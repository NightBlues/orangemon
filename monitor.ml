open Lwt
open Opium.Std

let temp_path = "/sys/class/hwmon/hwmon1/temp1_input"
(* let temp_path = "/sys/class/hwmon/hwmon0/temp1_input" *)
let redis_conn = ref None

let log msg =
  print_endline msg

let get_opt default = function None -> default| Some value -> value


type temp_t = {
    at: float;
    temp: int;
  } [@@deriving yojson]

let temp_data () =
  let time = Unix.time () in
  Lwt_io.with_file ~mode:Lwt_io.Input temp_path
                   (Lwt_io.read ~count:7)
  >>= fun temp ->
  let temp = int_of_string (String.trim temp) in
  let data = {at=time;temp=temp} in
  temp_t_to_yojson data |> Yojson.Safe.to_string |> return


let collector () =
  let conn = match !redis_conn with
    | None -> failwith "Connection to redis disappeared."
    | Some conn -> conn
  in
  let rec temp_col conn =
    temp_data ()
    >>= fun data -> Redis_lwt.Client.lpush conn "temp" data
    >>= fun _ -> Lwt_unix.sleep 30.
    >>= fun () -> temp_col conn
  in
  temp_col conn


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
      let converter temp =
        let temp = Yojson.Safe.from_string temp |> temp_t_of_yojson in
        match temp with
        | Ok temp -> `List [`Float temp.at; `Int temp.temp]
        | Error e -> failwith ("Error in temp data: " ^ e)
      in
      let lines = List.map converter lines in
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
     (collector () <&> http_app_thread))
