defmodule Axon.Schedules do
  @moduledoc """
  Parameter Schedules.

  Parameter schedules are often used to anneal hyperparameters
  such as the learning rate during the training process. Schedules
  provide a mapping from the current time step to a learning rate
  or another hyperparameter.

  Choosing a good learning rate and consequently a good learning
  rate schedule is typically a process of trial and error. Learning
  rates should be relatively small such that the learning curve
  does not oscillate violently during the training process, but
  not so small that learning proceeds too slowly. Using a
  schedule slowly decreases oscillations during the training
  process such that, as the model converges, training also
  becomes more stable.

  All of the functions in this module are implemented as
  numerical functions and can be JIT or AOT compiled with
  any supported `Nx` compiler.

  """

  import Nx.Defn
  import Axon.Shared

  @doc ~S"""
  Exponential decay schedule.

  $$\gamma(t) = \gamma_0 * r^{\frac{t}{k}}$$

  ## Options

    * `:init_value` - inital value. $\gamma$ in above formulation.
      Defaults to `1.0e-2`
    * `:decay_rate` - rate of decay. $r$ in above formulation.
      Defaults to `0.95`
    * `:transition_steps` - steps per transition. $k$ in above
      formulation. Defaults to `10`
    * `:transition_begin` - step to begin transition. Defaults to `0`
    * `:staircase` - discretize outputs. Defaults to `false`

  ## Examples

      iex> Axon.Schedules.exponential_decay(5)
      #Nx.Tensor<
        f64
        0.009746794344808964
      >

      iex> Axon.Schedules.exponential_decay(10, staircase: true, transition_steps: 5)
      #Nx.Tensor<
        f64
        0.009025
      >

  """
  defn exponential_decay(step, opts \\ []) do
    opts =
      keyword!(opts,
        init_value: 1.0e-2,
        decay_rate: 0.95,
        transition_steps: 10,
        transition_begin: 0,
        staircase: false
      )

    step = Nx.subtract(step, opts[:transition_begin])

    p =
      if to_predicate(opts[:staircase]) do
        Nx.floor(step / opts[:transition_steps])
      else
        step / opts[:transition_steps]
      end

    Nx.select(
      Nx.less_equal(step, 0),
      opts[:init_value],
      opts[:init_value] * Nx.power(opts[:decay_rate], p)
    )
  end

  @doc ~S"""
  Cosine decay schedule.

  $$\gamma(t) = \gamma_0 * (1 - \alpha)*(\frac{1}{2}(1 + \cos{\pi \frac{t}{k}})) + \alpha$$

  ## Options

    * `:init_value` - initial value. $\gamma_0$  in above formulation.
      Defaults to `1.0e-2`
    * `:decay_steps` - number of steps to apply decay for.
      $k$ in above formulation. Defaults to `10`
    * `:alpha` - minium value of multiplier adjusting learning rate.
      $\alpha$ in above formulation. Defaults to `0.0`

  ## Examples

      iex> Axon.Schedules.cosine_decay(5)
      #Nx.Tensor<
        f64
        0.005
      >

      iex> Axon.Schedules.cosine_decay(1, decay_steps: 4)
      #Nx.Tensor<
        f64
        0.008535533905932738
      >

  ## References

    * [SGDR: Stochastic Gradient Descent with Warm Restarts](https://openreview.net/forum?id=Skq89Scxx&noteId=Skq89Scxx)

  """
  defn cosine_decay(step, opts \\ []) do
    pi = Nx.tensor(3.1415926535897932384626433832795028841971)
    opts = keyword!(opts, init_value: 1.0e-2, decay_steps: 10, alpha: 0.0)

    count = Nx.min(step, opts[:decay_steps])
    cosine_decay = 0.5 * (1 + Nx.cos(pi * count / opts[:decay_steps]))
    decayed = (1 - opts[:alpha]) * cosine_decay + opts[:alpha]

    opts[:init_value] * decayed
  end

  @doc ~S"""
  Constant schedule.

  $$\gamma(t) = \gamma_0$$

  ## Options

    * `:init_value` - initial value. $\gamma_0$ in above formulation.
      Defaults to `1.0e-2`

  ## Examples

      iex> Axon.Schedules.constant(100)
      #Nx.Tensor<
        f64
        0.01
      >

      iex> Axon.Schedules.constant(5, init_value: 1.0e-5)
      #Nx.Tensor<
        f64
        1.0e-5
      >

  """
  defn constant(_step, opts \\ []) do
    opts = keyword!(opts, init_value: 1.0e-2)
    Nx.tensor(opts[:init_value])
  end

  @doc ~S"""
  Polynomial schedule.

  $$\gamma(t) = (\gamma_0 - \gamma_n) * (1 - \frac{t}{k})^p$$

  ## Options

    * `:init_value` - initial value. $\gamma_0$ in above formulation.
      Defaults to `1.0e-2`
    * `:end_value` - end value of annealed scalar. $\gamma_n$ in above formulation.
      Defaults to `1.0e-3`
    * `:power` - power of polynomial. $p$ in above formulation. Defaults to `2`
    * `:transition_steps` - number of steps over which annealing takes place.
      $k$ in above formulation. Defaults to `10`

  ## Examples

      iex> Axon.Schedules.polynomial_decay(11)
      #Nx.Tensor<
        f64
        0.001
      >

      iex> Axon.Schedules.polynomial_decay(2, power: 1.5)
      #Nx.Tensor<
        f64
        0.007439875775199396
      >

  """
  defn polynomial_decay(step, opts \\ []) do
    opts =
      keyword!(opts,
        init_value: 1.0e-2,
        end_value: 1.0e-3,
        power: 2,
        transition_steps: 10,
        transition_begin: 0
      )

    count = Nx.clip(step - opts[:transition_begin], 0, opts[:transition_steps])
    frac = 1 - count / opts[:transition_steps]
    (opts[:init_value] - opts[:end_value]) * Nx.power(frac, opts[:power]) + opts[:end_value]
  end
end