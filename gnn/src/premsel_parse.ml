open Circuit;;
open Cnf;;
open Fof;;

let swap a i j =  
  let tmp = a.(i) in
  a.(i) <- a.(j);
  a.(j) <- tmp;;

let shuffle_array a =  
  let len = Array.length a in
  for i = 0 to len-1 do
    let r = i + Random.int (len - i) in
    swap a i r
  done;;

let shuffled l =
  let a = Array.of_list l in
  shuffle_array a;
  Array.to_list a

let load_premsel fname =
  Logic.copend ();
  let conjecture::axioms_ordered = List.rev (Fof_lexer.file fname)
  and fof_type (label, ft, fof) = ft in
  assert (fof_type conjecture = "conjecture");
  axioms_ordered |> (List.iter (fun (label, ft, fof) ->
    assert(ft = "axiom_useful" || ft = "axiom_redundant")));
  (* let axioms = shuffled axioms_ordered in  Shuffle should not affect anything, just to make sure that
					     the network cannot exploit a possible bug *)
  let axioms = axioms_ordered in
  let labels = axioms |> List.map (fun (label, ft, fof) -> if ft = "axiom_useful" then 1 else 0)
  in
  let to_cnf f = f |> (unfold_equiv true) |> miniscope |> rename_form |> nnf |> skolem |> noforall |> (dcnf []) in
  let remove_header (label, ft, fof) = fof in
  let to_cnf_rh f = f |> remove_header |> to_cnf in
  to_cnf (Neg (remove_header conjecture)), List.map to_cnf_rh axioms, labels;;

let premsel_cnf_to_indices (conjecture, axioms, labels) = 
  let circ = new circuit
  in
  let cl2circ cl =
    circ#empty_sub;
    List.map circ#get_lit cl in
  let conj_ind = List.map cl2circ conjecture
  and ax_ind = List.map (List.map cl2circ) axioms in
  let (
    (node_num, func_num, rel_num),
    terms, literals, node_types
   ) = circ#export ()
  and symbols = circ#export_symbols ()
  in
  let symbol_num = func_num + rel_num
  and func_to_fr (res, f, param) = (res, f, param, false)
  and rel_to_fr (res, r, param) =
    if r > 0 then (res, r-1+func_num, param, false)
    else (res, -r-1+func_num, param, true)
  in
  let clauses = conj_ind @ (List.concat ax_ind)
  and prob_lens = List.length conj_ind :: (List.map List.length ax_ind)
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
  and clause_types = List.rev_append
      (ListE.make (List.hd prob_lens) 0)
      (ListE.make (List.fold_left (+) 0 (List.tl prob_lens)) 1)
  and export_list l = (List.map List.length l, List.flatten l) in
  let export_array a = export_list (Array.to_list a)
  in
  (
   List.map export_array
     [ node_res_inputs; node_l_inputs; node_r_inputs; symbol_inputs ],
   [ export_array node_c_inputs; export_list clauses ],
   [ node_types; symbol_types; clause_types ],
     (*
       node_types: 0 = term, 1 = literal, 2 = variable
       symbol_types: 0 = function, 1 = relation
       clause_types: 0 = goals, 1 = path, 2 = axiom
      *)
   (prob_lens, labels, symbols)
  );;

let load_premsel_to_ind fname =
  premsel_cnf_to_indices (load_premsel fname);;
