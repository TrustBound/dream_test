//// A client for a weather API: the code under test of the guide "Test HTTP
//// calls with recordings". Each function takes the base request of the
//// API as a parameter, so a test can give it a request with a recorder.

import dream_http_client/client.{type ClientRequest}
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder

pub type Forecast {
  Forecast(city: String, high: Int, low: Int, summary: String)
}

pub type ForecastError {
  UnknownCity(city: String)
  RequestFailed(reason: String)
  BadBody(reason: String)
}

/// The forecast of a city, from `GET /v1/forecast/<city>`.
pub fn forecast(
  api: ClientRequest,
  city: String,
) -> Result(Forecast, ForecastError) {
  case api |> client.path("/v1/forecast/" <> city) |> client.send() {
    Ok(response) -> decode_forecast(response.body)
    Error(client.ResponseError(response:)) if response.status == 404 ->
      Error(UnknownCity(city))
    Error(client.ResponseError(response:)) ->
      Error(RequestFailed("HTTP " <> int.to_string(response.status)))
    Error(client.RequestError(error:)) ->
      Error(RequestFailed(client.transport_error_to_string(error)))
  }
}

fn decode_forecast(body: BitArray) -> Result(Forecast, ForecastError) {
  let decoder = {
    use city <- decode.field("city", decode.string)
    use high <- decode.field("high", decode.int)
    use low <- decode.field("low", decode.int)
    use summary <- decode.field("summary", decode.string)
    decode.success(Forecast(city:, high:, low:, summary:))
  }
  json.parse_bits(body, decoder)
  |> result.map_error(fn(error) { BadBody(string.inspect(error)) })
}

/// The message of each alert in the feed at `GET /stream/json`, which
/// sends one JSON object for each line, as the alerts happen.
pub fn alert_messages(api: ClientRequest) -> Result(List(String), String) {
  use chunks <- result.try(
    api
    |> client.path("/stream/json")
    |> client.stream_yielder()
    |> yielder.to_list()
    |> result.all()
    |> result.map_error(string.inspect),
  )
  // A line can arrive in two chunks, so join the chunks before the split
  use text <- result.try(
    chunks
    |> list.map(bytes_tree.to_bit_array)
    |> bit_array.concat
    |> bit_array.to_string
    |> result.replace_error("The feed is not UTF-8 text"),
  )
  text
  |> string.split("\n")
  |> list.filter(fn(line) { line != "" })
  |> list.try_map(fn(line) {
    json.parse(line, decode.at(["message"], decode.string))
    |> result.map_error(string.inspect)
  })
}
