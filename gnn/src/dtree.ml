open Cnf;;

module I2m = Map.Make(struct type t = (int * int) let compare = compare end);;
let i2m_find k m = try Some (I2m.find k m) with Not_found -> None;;
type 'a dt = Node of ('a dt) I2m.t * 'a list * 'a dt list;;

let empty_dt = Node (I2m.empty, [], []);;

let rec insert nv (Node(map, v, _)) = function
| [] -> Node(map, nv :: v, [])
| (A (f, args) :: rest) ->
    let l = List.length args in
    let child = try I2m.find (f, l) map with Not_found -> empty_dt in
    let new_child = insert nv child (args @ rest) in
    Node (I2m.add (f, l) new_child map, v, [])
| (V _ :: rest) ->
    let child = try I2m.find (0, 0) map with Not_found -> empty_dt in
    let new_child = insert nv child rest in
    Node (I2m.add (0, 0) new_child map, v, []);;

let rec find_jl skip (_, n) (Node (map, _, _) as ch) acc =
  let skip = skip + n - 1 in
  if skip = 0 then (if List.mem ch acc then acc else ch :: acc) else
  I2m.fold (find_jl skip) map acc;;

let rec update_jl (Node (map, v, _)) =
  let map = I2m.map update_jl map in
  Node (map, v, I2m.fold (find_jl 1) map []);;

let rec insert_jl nv (Node(map, v, jl)) = function
| [] -> Node(map, nv :: v, jl)
| (A (f, args) :: rest) ->
    let l = List.length args in
    let child = try I2m.find (f, l) map with Not_found -> empty_dt in
    let new_child = insert_jl nv child (args @ rest) in
    Node (I2m.add (f, l) new_child map, v, find_jl 1 (f, l) new_child jl)
| (V _ :: rest) ->
    let child = try I2m.find (0, 0) map with Not_found -> empty_dt in
    let new_child = insert nv child rest in
    Node (I2m.add (0, 0) new_child map, v, find_jl 1 (0, 0) new_child jl);;

let rec mem nv (Node(map, v, _)) = function
| [] -> List.mem nv v
| (A (f, args) :: rest) ->
    let l = List.length args in
    (try mem nv (I2m.find (f, l) map) (args @ rest) with Not_found -> false)
| (V _ :: rest) ->
    (try mem nv (I2m.find (0, 0) map) rest with Not_found -> false);;

let generalize tm net =
  let rec look acc (Node(map, v, _)) = function
      [] -> List.fold_left (fun sf x -> x :: sf) acc v
    | (A (f, args) :: rest) ->
        let l = List.length args in
        let acc =
          begin match i2m_find (0, 0) map with
          | None -> acc
          | Some ch -> look acc ch rest
          end in
        begin match i2m_find (f, l) map with
        | None -> acc
        | Some ch -> look acc ch (args @ rest)
        end
    | (V _ :: rest) ->
        match i2m_find (0, 0) map with
        | None -> acc
        | Some ch -> look acc ch rest in
  look [] net [tm];;

let rec unifs acc (Node(map, v, jl)) = function
  [] -> List.fold_left (fun sf x -> x :: sf) acc v
| (A (f, args) :: rest) ->
    let l = List.length args in
    let acc =
      begin match i2m_find (0, 0) map with
      | None -> acc
      | Some ch -> unifs acc ch rest
      end in
    begin match i2m_find (f, l) map with
    | None -> acc
    | Some ch -> unifs acc ch (args @ rest)
    end
| (V _ :: rest) -> List.fold_left (fun sf n -> unifs sf n rest) acc jl;;

let rec unifs_nojl acc (Node(map, v, _)) = function
  [] -> List.fold_left (fun sf x -> x :: sf) acc v
| (A (f, args) :: rest) ->
    let l = List.length args in
    let acc =
      begin match i2m_find (0, 0) map with
      | None -> acc
      | Some ch -> unifs_nojl acc ch rest
      end in
    begin match i2m_find (f, l) map with
    | None -> acc
    | Some ch -> unifs_nojl acc ch (args @ rest)
    end
| (V _ :: rest) -> I2m.fold (unifs_find_jl rest 1) map acc
and unifs_find_jl l skip (_, n) (Node (map, _, _) as ch) acc =
  let skip = skip + n - 1 in
  if skip = 0 then unifs_nojl acc ch l else
  I2m.fold (unifs_find_jl l skip) map acc;;


let rec trace_unifs s acc ((Node(map, v, jl)) as dt) = function
  [] -> List.fold_left (fun sf x -> x :: sf) acc v
| (A (f, args) :: rest) ->
    let l = List.length args in
    let acc =
      begin match i2m_find (0, 0) map with
      | None -> acc
      | Some ch -> trace_unifs s acc ch rest
      end in
    begin match i2m_find (f, l) map with
    | None -> acc
    | Some ch -> trace_unifs s acc ch (args @ rest)
    end
| (V i :: rest) ->
    match subst_get s i with
      None -> List.fold_left (fun sf n -> trace_unifs s sf n rest) acc jl
    | Some t -> trace_unifs s acc dt (t :: rest);;

let trace_unifs sub dt tms = trace_unifs sub [] dt tms;;

(*
open Cnf;;
open Dtree;;

#install_printer Fof.pp_print_term;;
Hashtbl.add Fof_parse.no_cnst 1 "a";;
Hashtbl.add Fof_parse.no_cnst 2 "b";;
Hashtbl.add Fof_parse.no_cnst 3 "c";;
Hashtbl.add Fof_parse.no_cnst 6 "f";;
Hashtbl.add Fof_parse.no_cnst 7 "g";;

let a =  A(1, []);;
let b =  A(2, []);;
let c =  A(3, []);;
let gab = A(7, [a; b]);;
let gax = A(7, [a; V 1]);;
let gxc = A(7, [V 1; c]);;
let gxb = A(7, [V 1; b]);;
let gbc = A(7, [b; c]);;

let t1 = A(6, [gax; c]);;
let t2 = A(6, [gxb; V 2]);;
let t3 = A(6, [gab; a]);;
let t4 = A(6, [gxc; b]);;
let t5 = A(6, [V 3; V 4]);;
let t6 = A(6, [gbc; V 2]);;

let dt = update_jl (List.fold_left (fun sf x -> insert x sf [x]) empty_dt [t1; t2; t3; t4; t5; t6]);;

let gbx = A(7, [b; V 5]);;
let t = A(6, [gbx; a]);;

generalize t dt;;
unifs [] dt [t];;
*)
