open Lwt
open Opium.Std

let _connect_redis () =
  let open Redis_lwt.Client in
  connect {host="localhost";port=6379}

let redis_conn = Lwt_pool.create 3 _connect_redis

let log msg =
  print_endline msg

let get_opt default = function None -> default| Some value -> value


let index_view =
  let index_view_ req =
    let headers = Cohttp.Header.init_with "content-type" "text/html" in
    Cohttp_lwt_unix.Server.respond_file ~headers ~fname:"template/index.html" ()
    >>= fun resp -> Opium_kernel.Rock.Response.of_response_body resp |> return
  in
  get "/" index_view_


let view collection converter req =
  let num = Uri.get_query_param (Request.uri @@ req) "n" in
  let num = int_of_string @@ get_opt "10" @@ num in
  let%lwt lines =
    Lwt_pool.use redis_conn (fun conn ->
                   Redis_lwt.Client.lrange conn collection 0 num)
  in
  let data =
    let lines = List.map converter lines in
    `Assoc [("result", (`List [(`List lines)]))]
    |> Yojson.Safe.to_string
  in
  let headers = Cohttp.Header.init_with "Content-Type" "application/json" in
  `String data |> Opium_app.respond' ~headers

let cputemp_view =
  let view_ = view "temp" Collector.converter_temp in
  get "/cputemp.json" view_

let pings_view =
  let view_ = view "pings" Collector.converter_ping in
  get "/pings.json" view_


let () =
  let http_app =
    App.empty |> index_view |> cputemp_view |> pings_view
    |> Opium.Std.middleware
         (Opium.Std.Middleware.static ~local_path:"static" ~uri_prefix:"/static")
    |> App.run_command'
  in
  let http_app_thread = match http_app with
    | `Ok thread -> thread
    | _ -> log "Could not launch http server."; return_unit
  in
  Lwt_main.run
    (Collector.collector redis_conn () <&> http_app_thread)
