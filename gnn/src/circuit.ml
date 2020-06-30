open Cnf;;
open Logic;;

module IM = Map.Make(struct type t = int let compare = compare end);;
module LIM = Map.Make(struct type t = (int * int list) let compare = compare end);;

(*  Old version of ocaml does not support find_opt  *)
let im_find_opt key dict =
  if IM.mem key dict then Some (IM.find key dict)
  else None;;
let lim_find_opt key dict =
  if LIM.mem key dict then Some (LIM.find key dict)
  else None;;
let cnf_im_find_opt key dict =
  if Cnf.Im.mem key dict then Some (Cnf.Im.find key dict)
  else None;;




let map_to_list_IM m =
  IM.fold ( fun input res t -> (res, input) :: t) m [];;
let map_to_list_LIM m =
  LIM.fold ( fun (f, a) res t -> (res, f, a) :: t) m [];;
let ar_append a i x =
  (* print_string "ar_append ";
  print_int (Array.length a);
  print_string " <- ";
  print_int i;
  print_string "\n";
  Format.print_flush (); *)
  a.(i) <- (x :: a.(i) );;
let compose f g = fun x -> f (g x);;

module ListE = struct
  let make i x =
    if i < 0 then invalid_arg "List.make";
    let rec loop x acc = function
      | 0 -> acc
      | i -> loop x (x::acc) (i-1)
    in
    loop x [] i
end

class circuit =
  object(self)
    val mutable sub = Cnf.Im.empty;
    val mutable next_node = 0;
    val mutable node_types_rev = [];
    val mutable cur_vartype = 2;
    val mutable next_func = 0;
    val mutable next_rel = 1;
    val mutable funcs = IM.empty;
    val mutable rels = IM.empty;
    val mutable vars = IM.empty;
    val mutable terms = LIM.empty;
    val mutable literals = LIM.empty;
    method get_func f =
      match im_find_opt f funcs with
      | Some fn -> fn
      | None ->
	  let fn = next_func in
	  next_func <- next_func+1;
	  funcs <- IM.add f fn funcs;
	  fn
    method get_rel r =
      let (s,v) = if r >= 0 then (1,r) else (-1,-r) in
      match im_find_opt v rels with
      | Some rn -> s*rn
      | None ->
	  let rn = next_rel in
	  next_rel <- next_rel+1;
	  rels <- IM.add v rn rels;
	  s*rn
    method get_var x =
      match im_find_opt x vars with
      | Some node -> node
      | None ->
	  let node =
	    match cnf_im_find_opt x sub with
	    | None ->
		let n = next_node in
		next_node <- next_node+1;
		node_types_rev <- cur_vartype :: node_types_rev;
		n
	    | Some t -> self#get_term t
	  in
	  vars <- IM.add x node vars;
	  node
    method get_term = function
      | Cnf.V x -> self#get_var x
      | Cnf.A (f, subterms) ->
	  let fn = self#get_func f
	  and subnodes = List.map self#get_term subterms in
	  match lim_find_opt (fn, subnodes) terms with
	  | Some node -> node
	  | None ->
	      let node = next_node in
	      next_node <- next_node+1;
	      node_types_rev <- 0 :: node_types_rev;
	      terms <- LIM.add (fn, subnodes) node terms;
	      node
    method get_lit (r, subterms) =
      let rn = self#get_rel r
      and subnodes = List.map self#get_term subterms in
      (* print_string "  Rel: ";
      print_int r;
      print_string " -> ";
      print_int rn;
      print_string "\n";
      Format.print_flush (); *)
      match lim_find_opt (rn, subnodes) literals with
      | Some node -> node
      | None ->
	  let node = next_node in
	  next_node <- next_node+1;
	  node_types_rev <- 1 :: node_types_rev;
	  literals <- LIM.add (rn, subnodes) node literals;
	  node
    method new_sub nsub =
      sub <- nsub;
      vars <- IM.empty
    method empty_sub = self#new_sub Cnf.Im.empty
    method other_vartype () =
      cur_vartype <- 3
    method export () =
      (
       (next_node, next_func, next_rel-1),
       map_to_list_LIM terms,
       map_to_list_LIM literals,
       List.rev node_types_rev
      )
    method export_symbols () =
      let func_a = Array.make next_func 0
      and rel_a = Array.make (next_rel-1) 0 in
      funcs |> IM.iter (fun symb i -> func_a.(i) <- symb);
      rels  |> IM.iter (fun symb i -> rel_a.(i-1) <- symb);
      let func_l = Array.to_list func_a
      and rel_l = Array.to_list rel_a
      and tostr s = Hashtbl.find Cnf.no_cnst s in
      (
       List.map tostr func_l,
       List.map tostr rel_l
      )
  end;;

let state_to_circuit st =
  let circ = new circuit
  and (sub,_) = st.sub in
  circ#new_sub sub;
  let path = List.map circ#get_lit st.path
  and goals = List.map circ#get_lit (
    List.concat (st.clause :: (List.map (fun (_, _, _, c, _) -> c) st.stack))
    )
  and cl2circ cl =
    circ#empty_sub;
    List.map circ#get_lit cl in
  circ#other_vartype ();
  let axioms = List.map cl2circ !Logic.cur_matrix in
  (circ, path, goals, axioms)

let state_to_gr_symbols st =
  let (circ, path, goals, axioms) = state_to_circuit st in
  circ#export_symbols ()

let state_to_gr_indices st =
  let (circ, path, goals, axioms) = state_to_circuit st in
  let (
    (node_num, func_num, rel_num),
    terms, literals, node_types
   ) = circ#export ()
  in
  assert (List.length node_types == node_num);
  let symbol_num = func_num + rel_num
  and func_to_fr (res, f, param) = (res, f, param, false)
  and rel_to_fr (res, r, param) =
    if r > 0 then (res, r-1+func_num, param, false)
    else (res, -r-1+func_num, param, true)
  in
  let path_len = List.length path
  and ax_num = List.length axioms
  in
  let clauses = List.concat [ [goals]; List.map (fun x -> [x]) path; axioms]
  in
  let node_res_inputs = Array.make node_num []
  and node_l_inputs = Array.make node_num []
  and node_r_inputs = Array.make node_num []
  and symbol_inputs = Array.make symbol_num []
  and node_c_inputs = Array.make node_num []
  in

  clauses |> List.iteri (fun i cl ->
    cl |> List.iter (fun li ->
      ar_append node_c_inputs li i
    )
  );

  let save_fr (res, s, param, b) =
    let save_pair x y =
      ar_append node_res_inputs res (s, x, y, b);
      if x >= 0 then ar_append node_l_inputs x (s, res, y, b);
      if y >= 0 then ar_append node_r_inputs y (s, res, x, b);
      ar_append symbol_inputs s (res, x, y, b) in
    let rec save_list = function
      | [] -> save_pair (-1) (-1)
      | [x] -> save_pair x (-1)
      | [x;y] -> save_pair x y
      | x::y::tl -> save_pair x y; save_list (y::tl) in
    save_list param in
  List.iter (compose save_fr func_to_fr) terms;
  List.iter (compose save_fr rel_to_fr) literals;

  let symbol_types = List.rev_append (ListE.make func_num 0) (ListE.make rel_num 1)
  and clause_types = List.concat [ [0] ; (ListE.make path_len 1) ; (ListE.make ax_num 2) ]
  and export_list l = (List.map List.length l, List.flatten l) in
  let export_array a = export_list (Array.to_list a)
  in
  (
   List.map export_array
     [ node_res_inputs; node_l_inputs; node_r_inputs; symbol_inputs ],
   [ export_array node_c_inputs; export_list clauses ],
   [ node_types; symbol_types; clause_types ]
     (*
       node_types: 0 = term, 1 = literal, 2 = variable, 3 = variable in axiom
       symbol_types: 0 = function, 1 = relation
       clause_types: 0 = goals, 1 = path, 2 = axiom
      *)
  )
