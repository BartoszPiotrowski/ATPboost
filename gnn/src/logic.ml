open Cnf;;
open Fof;;
open Features;;
open Args;;
open Format;;

let infer = ref 0;;

(* Each DB entry is a hashtable of discrimination trees, which keep:
     (lit-arguments, rest-clause, vars, contrapositive)
        (term list * lit list    * int * int)   *)
let db = Hashtbl.create 10017;;

let eq (sub, off) l1 l2 = eq_lit sub l1 l2;;

let unify (sub, off) l1 l2 = try Some (unify_lit sub l1 l2, off) with Unify -> None;;

let unify_rename (s, off) args1 (args2, rest, vars) =
  try Some(if vars = 0 then ((unify_list s args1 args2, off), rest) else
    let s, rest = unify_rename_subst off args1 args2 s rest in ((s, off + vars), rest))
  with Unify -> None;;

type state = {
  sub : Cnf.term Cnf.Im.t * int; (* current substitution *)
  path : Cnf.lit list; (* current path - literals assumed at the current context *)
  lem : Cnf.lit list; (* lemmas - statements already proven in the context *)
  clause : Cnf.lit list; (* remaining current literals *)
  pcnr : int list; (* list of numbers of the previous contrapositives used *)
  stack : (state * Cnf.lit list * Cnf.lit list * Cnf.lit list * int list) list; (* other remaining goals, what are "olds"? *)
}

let fold_goals f st s = List.fold_left (List.fold_left f) st (s.clause :: (List.map (fun (_, _, _, c, _) -> c) s.stack));;
let goals_length s = fold_goals (fun sf _ -> sf + 1) 0 s;;
let goals_size s = fold_goals (lit_size (fst s.sub)) 0 s;;

let action_contr = Hashtbl.create 1000;;

let solved = Hashtbl.create 1000;;
let is_solved st = Hashtbl.mem solved st;;

let rec prove s = match s.clause with
| [] ->
    begin match s.stack with
    | [] -> 1, (s, [])
    | (olds, path, lem, clause, pcnr) :: stack -> if !save_above >= 0 then Hashtbl.replace solved olds (); prove {s with path; lem; clause; pcnr; stack}
    end
| (lit1 :: rest) as clause ->
    if (List.exists (fun x -> List.exists (eq s.sub x) s.path)) clause then -1, (s, []) else
    if List.exists (eq s.sub lit1) s.lem then prove {s with clause = rest} else
    let neglit = negate lit1 in
    let rec reduce = function
      | plit :: pt -> begin
          match unify s.sub neglit plit with
          | Some sub2 -> prove {s with sub = sub2; clause = rest}
          | None -> reduce pt end
      | [] ->
         let actions = try Dtree.trace_unifs (fst s.sub) (Hashtbl.find db (fst neglit)) (snd neglit) with Not_found -> [] in
         let actions = if !pre_unify then List.filter (fun a -> unify_rename s.sub (snd (List.hd s.clause)) (Hashtbl.find action_contr a) <> None) actions else actions in
         0, (s, actions)
    in reduce s.path
and extend s action =
  let lit1, rest = match s.clause with h :: t -> h, t | _ -> assert false in
  let triple = Hashtbl.find action_contr action in
  match unify_rename s.sub (snd lit1) triple with
  | Some (sub, clause) ->
     incr infer;
     let stack = (s, s.path, lit1 :: s.lem, rest, action :: s.pcnr) :: s.stack in
     let path = lit1 :: s.path in
     prove {s with sub; path; clause; stack}
  | _ -> (-1, (s, []));;

let rec iter_rest acc fnctn = function
  [] -> ()
| h :: t -> fnctn h (List.filter (fun x -> x <> (-hash, []))
             (List.rev_append acc t)); iter_rest (h :: acc) fnctn t;;

let init_state = {
  sub = (empty_sub, 0);
  path = [];
  lem = [];
  clause = [(hash,[])];
  pcnr = [];
  stack = []
}

let prn_cls_tstp cl =
  let s = string_of_clause_tstp (lsetify cl) in
  let md = (* md5s *) Digest.to_hex (Digest.string s)  in
    printf "cnf(a_%s,axiom,%s).\n" md s;;

let copend () =
  infer := 0;
  Hashtbl.clear var_no;
  Hashtbl.clear no_var;
  var_num := 0;
  Hashtbl.clear cnst_no;
  Hashtbl.clear no_cnst;
  Hashtbl.clear contr_no;
  Hashtbl.clear no_contrstr;
  Hashtbl.clear no_contrfea;
  Hashtbl.clear no_contrholstep;
  Hashtbl.clear no_contrvars;
  Hashtbl.clear db;
  Hashtbl.clear action_contr;
  Hashtbl.clear solved;
  if eqn <> pred_number "=" || hash <> pred_number "'#'" then failwith "copend eqn";;

let cur_matrix = ref [];;
let total_action = ref 0;;
let hash_to_fl_index_htbl = Hashtbl.create 10017;;
let hash_to_fl_index hash = Hashtbl.find hash_to_fl_index_htbl hash;;

let start file =
  copend ();
  let get_model_fea = read_model_fea "fea_model" "fea_model_map" in
  let (ths, gl) = Fof_lexer.problem file in
  let gl = if !conj then Conj(hasht, gl) else gl in
  let forms = equal_axioms (Neg gl :: ths) in
  let precnf = List.map (fun f -> noforall (skolem (nnf (rename_form (miniscope (unfold_equiv true f)))))) forms in
  let mat =
    if !def then List.map (fun x -> fst (rename_unbound_clause x)) (List.fold_left dcnf [] precnf)
    else List.fold_left matrix [] (List.map cnf precnf) in
  let mat = List.filter (fun cl -> List.for_all (fun (p1,a1) ->
    List.for_all (fun (p2,a2) -> p1 <> -p2 || a1 <> a2) cl) cl) mat in
  let order_setify l =
    let h = Hashtbl.create (List.length l * 2) in
    List.rev (List.fold_left (fun sf x -> if Hashtbl.mem h x then sf else (Hashtbl.add h x (); x :: sf)) [] l) in
  let mat = List.map (fun l -> List.rev (order_setify (List.rev l))) mat in
  cur_matrix := mat;
  (* Uncomment to print the clauses *)
  (* List.iter prn_cls_tstp mat; *)
  let predb = Hashtbl.create 100
  and fl_index_to_hash = ref [] in
  let cl2predb cl =
    let max_var = 1 + List.fold_left (fun sf (_, t) -> List.fold_left max_var sf t) (-1) cl in
    let cl = if not !conj && List.for_all (fun (p, _) -> p < 0) cl &&
      not (List.mem (-hash, []) cl) then (-hash, []) :: cl else cl in
    let contr_hash lit rest = contr_number get_model_fea (lit :: rest) (string_of_contr lit rest) in
    iter_rest [] (fun (p,tl) rest ->
      let hash = contr_hash (p, tl) rest in
      Hashtbl.add predb p
	(tl, rest, max_var, hash);
      fl_index_to_hash := hash :: !fl_index_to_hash
		 ) (List.rev cl) in
  List.iter cl2predb mat;
  fl_index_to_hash := List.rev !fl_index_to_hash;
  !fl_index_to_hash |> List.iteri (fun i h -> Hashtbl.add hash_to_fl_index_htbl h i);
  total_action := List.length !fl_index_to_hash;

  Hashtbl.clear db;
  let preds = Hashtbl.fold (fun k _ sf -> Im.add k () sf) predb Im.empty in
  let cl2db k () =
    let vd = List.rev (Hashtbl.find_all predb k) in
    List.iter (fun (args, rest, vars, cno) -> Hashtbl.add action_contr cno (args, rest, vars)) vd;
    let dt = Dtree.update_jl (List.fold_left (fun sf (a, _, _, cno) -> Dtree.insert cno sf a) Dtree.empty_dt vd) in
    Hashtbl.add db k dt;
  in
  Im.iter cl2db preds;
  (*let allcos = Hashtbl.fold (fun c _ sf -> c :: sf) no_contrstr [] in*)
  prove init_state
;;

let print_state st addfea =
  let s = fst (st.sub) in
  let stack = List.concat (List.map (fun (_t, pat, _lem, cl, _) -> cl) st.stack) in
  let slit, spath, slem = inst_lit s (List.hd st.clause), List.map (inst_lit s) st.path, List.map (inst_lit s) st.lem in
  let sstack = List.map (inst_lit s) stack in
  print_string "("; pp_print_lit std_formatter slit; print_string "),\n";
  print_string "  ("; pp_iter std_formatter pp_print_lit "," spath; print_string "),\n";
  print_string "  ("; pp_iter std_formatter pp_print_lit "," slem; print_string "),\n";
  print_string "  ("; pp_iter std_formatter pp_print_lit "," sstack; print_string "),\n";
  print_string "  ("; pp_print_lit std_formatter (List.hd st.clause); print_string "),\n";
  print_string "  ("; pp_iter std_formatter pp_print_lit "," st.path; print_string "),\n";
  print_string "  ("; pp_iter std_formatter pp_print_lit "," st.lem; print_string "),\n";
  print_string "  ("; pp_iter std_formatter pp_print_lit "," stack; print_string "),\n";
  print_string "  ("; pp_iter std_formatter (fun fmt (a,b) -> pp_print_int fmt a; pp_print_char fmt ','; pp_print_int fmt b) "," addfea; print_string ")";;

let fprint_state fmt st addfea =
  let s = fst (st.sub) in
  let stack = List.concat (List.map (fun (_t, pat, _lem, cl, _) -> cl) st.stack) in
  let slit, spath, slem = inst_lit s (List.hd st.clause), List.map (inst_lit s) st.path, List.map (inst_lit s) st.lem in
  let sstack = List.map (inst_lit s) stack in
  fprintf fmt "("; pp_print_lit fmt slit; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt pp_print_lit "," spath; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt pp_print_lit "," slem; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt pp_print_lit "," sstack; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_print_lit fmt (List.hd st.clause); fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt pp_print_lit "," st.path; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt pp_print_lit "," st.lem; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt pp_print_lit "," stack; fprintf fmt "),\n";
  fprintf fmt "  ("; pp_iter fmt (fun fmt (a,b) -> pp_print_int fmt a; pp_print_char fmt ','; pp_print_int fmt b) "," addfea; fprintf fmt ")";;

Random.self_init ();;

exception ResourceOut of string;;

let cleanexit _ = raise (ResourceOut "Signal");;
Sys.signal Sys.sigint (Sys.Signal_handle cleanexit);;
Sys.signal Sys.sigterm (Sys.Signal_handle cleanexit);;

(* User time: use Unix.gettimeofday only on colo12 *)
let gettime () = Sys.time ();;
let start_time = gettime ();;

(* 10 artificial features *)
let global_features maxf st =
  let goals_length = goals_length st in  (* 18 *)
  let goals_size = goals_size st in
  let goals_max = fold_goals (fun sf l -> max sf (lit_size (fst st.sub) 0 l)) 0 st in
  let path_len = List.length st.path in
  let sub_len = snd st.sub in (* 22 *)
  let max_depth = fold_goals (fun sf l -> max sf (lit_depth (fst st.sub) l)) 0 st in
  let p_vars = Im.cardinal (List.fold_left (lit_vars (fst st.sub)) Im.empty st.path) in
  let g_vars = Im.cardinal (fold_goals (lit_vars (fst st.sub)) Im.empty st) in
  let ((mk1, mv1), (mk2, mv2)) = most_common (fold_goals (update_freq_lit (fst st.sub)) Im.empty st) in
  [(maxf+1,goals_length); (maxf+2,goals_size); (maxf+3,goals_max); (maxf+4,path_len); (maxf+5, sub_len); (maxf+6, max_depth); (maxf+7, mk1); (maxf+8, mv1); (maxf+9, mk2); (maxf+10, mv2); (maxf+11, p_vars); (maxf+12, g_vars); (maxf+13, try List.hd st.pcnr with _ -> -1); (maxf+14, try List.hd (List.tl st.pcnr) with _ -> -1); (maxf+15, try List.hd (List.tl (List.tl st.pcnr)) with _ -> -1)];;

(* features of current literal, features of the path *)
let goal_features state =
  let lfea = ubit2_list (fst state.sub) [] [List.hd state.clause]
  and pfea = ubit2_list (fst state.sub) [] state.path in
  lfea @ List.map (fun (x,n) -> (x + features_modulo, n)) pfea;;

(* features of all goals, features of the path, global features *)
let state_features st =
  let nstack = List.concat (List.map (fun (_, _pat, _lem, cl, _) -> cl) st.stack) in
  let gfea = ubit2_list (fst st.sub) [] (st.clause @ nstack) in
  let pfea = List.map (fun (x,n) -> (x + features_modulo, n)) (ubit2_list (fst st.sub) [] st.path) in
  gfea @ pfea @ (global_features (features_modulo * 2) st)
;;


let contr_features c = Hashtbl.find Features.no_contrfea c;;
