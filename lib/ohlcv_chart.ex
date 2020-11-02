defmodule OhlcvChart do
  alias DateTime, as: DT
  alias Decimal, as: D
  alias Enum, as: E
  use TypedStruct

  @minute 60 * 1000

  typedstruct module: Bar do
    field :o, String.t()
    field :h, String.t()
    field :l, String.t()
    field :c, String.t()
    field :v, String.t()
    field :t, pos_integer()
  end

  typedstruct module: Chart do
    field :clock_start, pos_integer(), enforce: true
    field :period, pos_integer(), enforce: true
    field :chart, List.t(), default: []
    field :timeframe, pos_integer(), default: 1000 * 60 * 10
    field :max_length, pos_integer()
  end

  def now, do: DT.now!("Etc/UTC") |> DT.to_unix()

  def new!(period \\ @minute, timeframe \\ @minute * 10, start \\ now())
      when rem(timeframe, period) == 0 and is_integer(timeframe) do
    %Chart{
      clock_start: start,
      period: period,
      timeframe: timeframe,
      max_length: div(timeframe, period)
    }
  end

  def form_bar(nil, %{o: o, h: h, l: l, c: c, t: t, v: v}),
    do: %Bar{o: o, h: h, l: l, c: c, t: t, v: v}

  def form_bar(
        bar = %Bar{o: o1, h: h1, l: l1, c: c1, t: t1, v: v1},
        %{o: o2, h: h2, l: l2, c: c2, t: t2, v: v2}
      ) do
    {open, close, time} =
      case {t1, t2} do
        {nil, _} -> {o2, c2, t2}
        {prev, next} when next > prev -> {o1, c2, t2}
        {prev, next} when next < prev -> {o2, c1, t1}
      end

    Map.merge(bar, %{
      o: open,
      h: D.max(h1, h2) |> D.to_string(),
      l: D.min(l1, l2) |> D.to_string(),
      c: close,
      v: D.add(v1, v2) |> D.to_string(),
      t: time
    })
  end

  def form_bar(nil, %{price: p, volume: v, time: t})
      when is_binary(p) and is_binary(v) and is_integer(t),
      do: %Bar{o: p, h: p, l: p, c: p, t: t, v: v}

  def form_bar(
        %Bar{o: o, h: h, l: l, c: c, v: v1, t: t1},
        %{price: p, volume: v2, time: t2}
      )
      when is_integer(t2) and
             is_integer(t1) and
             is_binary(o) and
             is_binary(h) and
             is_binary(l) and
             is_binary(p) do
    if t2 > t1 do
      %Bar{
        o: o,
        c: p,
        h: D.to_string(D.max(h, p)),
        l: D.to_string(D.min(l, p)),
        v: D.to_string(D.add(v1, v2)),
        t: t2
      }
    else
      %Bar{
        o: p,
        c: c,
        h: D.to_string(D.max(h, p)),
        l: D.to_string(D.min(l, p)),
        v: D.to_string(D.add(v1, v2)),
        t: t1
      }
    end
  end

  def get_start_timestamp(%Chart{clock_start: start, period: period}, timestamp)
      when is_integer(timestamp) do
    div(timestamp - start, period) * period + start
  end

  def get_end_timestamp(%Chart{clock_start: start, period: period}, timestamp)
      when is_integer(timestamp) do
    ceil((timestamp - start) / period) * period + start
  end

  def step(
        state = %Chart{chart: chart_list, max_length: max_len},
        %{price: price, volume: volume, time: timestamp}
      )
      when is_binary(price) and
             is_binary(volume) and
             is_integer(max_len) and
             is_integer(timestamp) and
             max_len > 0 do
    end_timestamp = get_end_timestamp(state, timestamp)
    start_timestamp = get_start_timestamp(state, timestamp)

    case chart_list do
      [] ->
        [form_bar(nil, %{price: price, volume: volume, time: end_timestamp})]

      [head = %Bar{t: ^end_timestamp} | tail] ->
        [form_bar(head, %{price: price, volume: volume, time: end_timestamp}) | tail]

      [%Bar{t: ^start_timestamp} | _] ->
        case [form_bar(nil, %{price: price, volume: volume, time: end_timestamp}) | chart_list] do
          new_list when length(new_list) > max_len -> new_list |> E.take(max_len)
          new_list -> new_list
        end
    end
    |> update_chart_list(state)
  end

  def update_chart_list(list, state = %Chart{}) when is_list(list),
    do: %{state | chart: list}
end
