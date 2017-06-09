open Lwt
open Opium.Std

let redis_conn = ref None

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


let cputemp_view =
  let view req =
    let num = Uri.get_query_param (Request.uri @@ req) "n" in
    let num = int_of_string @@ get_opt "10" @@ num in
    let conn = match !redis_conn with
      | None -> failwith "Connection to redis disappeared."
      | Some conn -> conn
    in
    let%lwt lines = Redis_lwt.Client.lrange conn "temp" 0 num in
    let data =
      let lines = List.map Collector.converter lines in
      `Assoc [("result", (`List [(`List lines)]))]
      |> Yojson.Safe.to_string
    in
    let headers = Cohttp.Header.init_with "Content-Type" "application/json" in
    `String data |> Opium_app.respond' ~headers
  in
  get "/cputemp.json" view


let () =
  let http_app =
    App.empty |> index_view |> cputemp_view
    |> Opium.Std.middleware
         (Opium.Std.Middleware.static ~local_path:"static" ~uri_prefix:"/static")
    |> App.run_command'
  in
  let http_app_thread = match http_app with
    | `Ok thread -> thread
    | _ -> log "Could not launch http server."; return_unit
  in
  let connect_redis () =
    let open Redis_lwt.Client in
    let%lwt conn = connect {host="localhost";port=6379} in
    redis_conn := (Some conn);
    return_unit
  in
  Lwt_main.run
    (let%lwt () = connect_redis () in
     (Collector.collector redis_conn () <&> http_app_thread))
