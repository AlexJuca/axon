defmodule MixedPrecisionTest do
  use ExUnit.Case, async: true

  alias Axon.MixedPrecision.Policy
  alias Axon.MixedPrecision, as: AMP
  alias Axon.Training.Step

  describe "creation and application" do
    test "create policy" do
      assert %Policy{params: {:f, 32}, compute: {:bf, 16}, output: {:f, 32}} =
               AMP.create_policy(compute: {:bf, 16})

      assert %Policy{params: {:bf, 16}, compute: {:f, 32}, output: {:bf, 16}} =
               AMP.create_policy(params: {:bf, 16}, output: {:bf, 16})
    end

    test "apply_policy" do
      model =
        Axon.input({nil, 784})
        |> Axon.dense(128)
        |> Axon.batch_norm()
        |> Axon.dense(10)

      policy = AMP.create_policy(compute: {:bf, 16})

      assert %Axon{
               op: :dense,
               parent: %Axon{
                 op: :batch_norm,
                 parent: %Axon{op: :dense, policy: %Policy{compute: {:bf, 16}}},
                 policy: %Policy{compute: {:f, 32}}
               },
               policy: %Policy{compute: {:bf, 16}}
             } = AMP.apply_policy(model, policy, except: [:batch_norm])
    end
  end

  describe "compilation" do
    # TODO(seanmor5): Now that everything else has moved, maybe this
    # belongs in a train test or elsewhere
    test "correctly maintains parameter type after train step" do
      model =
        Axon.input({nil, 32})
        |> Axon.dense(2, name: "dense1")
        |> Axon.batch_norm(name: "batch_norm")
        |> Axon.dense(1, activation: :sigmoid, name: "dense2")

      policy = AMP.create_policy(params: {:bf, 16})

      mp_model = AMP.apply_policy(model, policy, except: [:batch_norm])

      %Step{init: init_fn, step: step_fn} =
        Axon.Training.step(mp_model, :binary_cross_entropy, Axon.Optimizers.sgd(0.01))

      state = init_fn.()

      state = Nx.Defn.jit(step_fn, [state, Nx.random_uniform({1, 32}), Nx.random_uniform({1, 1})])

      params = state[:params]

      assert Nx.type(params["dense1_kernel"]) == {:bf, 16}
      assert Nx.type(params["dense1_bias"]) == {:bf, 16}
      assert Nx.type(params["dense2_kernel"]) == {:bf, 16}
      assert Nx.type(params["dense2_bias"]) == {:bf, 16}
      assert Nx.type(params["batch_norm_gamma"]) == {:f, 32}
      assert Nx.type(params["batch_norm_beta"]) == {:f, 32}
    end
  end
end
