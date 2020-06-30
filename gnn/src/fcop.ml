open Premsel_parse;;
open Cnfpremsel_parse;;
open Format;;
open Logic;;
open Cnf;;
open Fof;;
open Circuit;;

let sts = ref [];;
let cop_start file =
  let (s, sta) as ret = Logic.start file in
  sts := [sta]; s, List.length (snd sta);;
let cop_action i =
  let (st, acs) = List.hd (!sts) in
  let (s, sta) as ret = Logic.extend st (List.nth acs i) in
  sts := sta :: !sts; s, List.length (snd sta);;
let cop_backtrack () = sts := List.tl !sts; if !sts = [] then failwith "Backtrack beyond start";;
let rec cop_restart () =
  match !sts with
    _ :: _ :: _ -> cop_backtrack (); cop_restart ()
  | [(_, acs)] -> (0, List.length acs)
  | [] -> failwith "Backtrack beyond start";;

let rec index v = function
  | [] -> 0
  | a::r when a = v -> 0
  | a::r -> 1 + index v r

let rec remove_doubles cmp = function
  | [] -> []
  | [a] -> [a]
  | a::b::r when (cmp a b) = 0 -> remove_doubles cmp (a::r)
  | a::b::r -> a::(remove_doubles cmp (b::r))

let sort_uniq cmp l = remove_doubles cmp (List.sort cmp l)

let cop_action_fl fli =
  let hashes = snd (List.hd !sts) in
  let hashes_sorted = hashes |> sort_uniq (fun x y -> compare (Logic.hash_to_fl_index x) (Logic.hash_to_fl_index y)) in
  let hash = List.nth hashes_sorted fli in
  cop_action (index hash hashes)

let cop_unif_mask () =
  let hashes = snd (List.hd !sts)
  and mask_ar = Array.make !Logic.total_action 0 in
  hashes |> List.iter (fun x ->
    mask_ar.(Logic.hash_to_fl_index x) <- 1;
  );
  Array.to_list mask_ar

let cop_act_to_actfl act =
  let hash = List.nth (snd (List.hd !sts)) act in
  let mask = cop_unif_mask () in
  let i = Logic.hash_to_fl_index hash in
  let rec sum_start = function
    | 0 -> fun _ -> 0
    | n -> function
	| [] -> 0
	| a::r -> a + (sum_start (n-1) r) in
  sum_start i mask

let cop_circuit_st () =
  let (st, acs) = List.hd (!sts) in
  let (circ, path, goals, axioms) = Circuit.state_to_circuit st in
  (circ#export (), path, goals, axioms)

let cop_graph_indices () =
  let (st, acs) = List.hd (!sts) in
  Circuit.state_to_gr_indices st

let cop_graph_symbols () =
  let (st, acs) = List.hd (!sts) in
  Circuit.state_to_gr_symbols st

let cop_contr_features i =
  List.map (fun (x, _) -> (x - 2 * Features.features_modulo)) (Hashtbl.find Features.no_contrfea (List.nth (snd (List.hd (!sts))) i));;
let cop_contr_represent i =
  Hashtbl.find Features.no_contrholstep (List.nth (snd (List.hd (!sts))) i);;
(*let cop_contr_print i =
  let s = Hashtbl.find Features.no_contrstr (List.nth (snd (List.hd (!sts))) i) in
  Format.print_string s; Format.print_flush ();;*)

let cop_st_print () =
  let (st, acs) = List.hd !sts in
  let s = fst (st.sub) in
  let stack = List.concat (List.map (fun (_t, pat, _lem, cl, _pcno) -> cl) st.stack) in
  let scl, spath, slem = List.map (inst_lit s) st.clause, List.map (inst_lit s) st.path, List.map (inst_lit s) st.lem in
  let sstack = List.map (inst_lit s) stack in
  print_string "Cla: ("; pp_iter std_formatter pp_print_lit "," scl; print_string ")\n";
  print_string "Path: ("; pp_iter std_formatter pp_print_lit "," spath; print_string ")\n";
  print_string "Lem:  ("; pp_iter std_formatter pp_print_lit "," slem; print_string ")\n";
  print_string "Stk:  ("; pp_iter std_formatter pp_print_lit "," sstack; print_string ")\n";
  List.iteri (fun n c -> Format.printf "Act%i: (%s)\n" n (Hashtbl.find Features.no_contrstr c)) acs;
  Format.print_flush ();;

let cop_print_symbols () =
  Cnf.no_cnst |> Hashtbl.iter (fun no cnst ->
    print_string cnst; print_string "\n";
  );
  Format.print_flush ();;

let cop_st_features () =
  let state = fst (List.hd !sts) in
  let litfea = if state.clause = [] then [] else Features.ubit2_list (fst state.sub) [] [List.hd state.clause] in
  let pfea = Features.ubit2_list (fst state.sub) [] state.path in
  let lemfea = Features.ubit2_list (fst state.sub) [] state.lem in
  let nstack = List.concat (List.map (fun (_, _pat, _lem, cl, _pcno) -> cl) state.stack) in
  let gfea = Features.ubit2_list (fst state.sub) [] ((if state.clause = [] then [] else List.tl state.clause) @ nstack) in
  (List.map fst litfea, List.map fst pfea, List.map fst lemfea, List.map fst gfea);;

let cop_st_features_fast () =
  let state = fst (List.hd !sts) in
  let litfea = if state.clause = [] then [] else Features.ubit2_list (fst state.sub) [] [List.hd state.clause] in
  List.map fst litfea;;

let cop_st_represent () =
  let state = fst (List.hd !sts) in
  let litrep = if state.clause = [] then [] else Features.holstep_list [List.hd state.clause] in
  let prep = Features.holstep_list state.path in
  let lemrep = Features.holstep_list state.lem in
  let nstack = List.concat (List.map (fun (_, _pat, _lem, cl, _pcno) -> cl) state.stack) in
  let grep = Features.holstep_list ((if state.clause = [] then [] else List.tl state.clause) @ nstack) in
  (litrep, prep, lemrep, grep);;

(*Logic.global_features;;*)
(*Logic.goals_length;;*)

let cop_all_contras () = Hashtbl.fold (fun c s sf -> (c, s) :: sf) Features.no_contrstr [];;
let cop_nos_contras () = snd (List.hd !sts);;

let _ = Callback.register "cop_start" cop_start;;
let _ = Callback.register "cop_action" cop_action;;
let _ = Callback.register "cop_backtrack" cop_backtrack;;
let _ = Callback.register "cop_restart" cop_restart;;

(*let _ = Callback.register "cop_contr_print" cop_contr_print;;*)
let _ = Callback.register "cop_contr_features" cop_contr_features;;
let _ = Callback.register "cop_contr_represent" cop_contr_represent;;

let _ = Callback.register "cop_st_print" cop_st_print;;
let _ = Callback.register "cop_st_features" cop_st_features;;
let _ = Callback.register "cop_st_features_fast" cop_st_features_fast;;
let _ = Callback.register "cop_st_represent" cop_st_represent;;

let _ = Callback.register "cop_all_contras" cop_all_contras;;
let _ = Callback.register "cop_nos_contras" cop_nos_contras;;

let _ = Callback.register "cop_circuit_st" cop_circuit_st;;
let _ = Callback.register "cop_graph_indices" cop_graph_indices;;
let _ = Callback.register "cop_graph_symbols" cop_graph_symbols;;
let _ = Callback.register "cop_load_premsel" load_premsel_to_ind;;
let _ = Callback.register "cop_load_cnfpremsel" load_cnfpremsel_to_ind;;

let _ = Callback.register "cop_action_fl" cop_action_fl;;
let _ = Callback.register "cop_unif_mask" cop_unif_mask;;
let _ = Callback.register "cop_act_to_actfl" cop_act_to_actfl;;
let _ = Callback.register "cop_print_symbols" cop_print_symbols;;
