open Cnf;;

let content_names = ref true;;

(* For efficiency in CNF: int * term list, with negative for negation *)
let negate (i, l) = (-i, l);;

let rec max_var a = function
    V x -> max a x
  | A (_, l) -> List.fold_left max_var a l;;

let rec unfold_equiv polar = function
    Forall (x, t) -> Forall (x, unfold_equiv polar t)
  | Exists (x, t) -> Exists (x, unfold_equiv polar t)
  | Conj (l, r) -> Conj (unfold_equiv polar l, unfold_equiv polar r)
  | Disj (l, r) -> Disj (unfold_equiv polar l, unfold_equiv polar r)
  | Neg t -> Neg (unfold_equiv (not polar) t)
  | Eqiv (l, r) ->
      let lp = unfold_equiv polar l and rp = unfold_equiv polar r in
      let ln = unfold_equiv (not polar) l and rn = unfold_equiv (not polar) r in
      if polar then Conj (Disj (Neg ln, rp), Disj (Neg rn, lp))
      else Disj (Conj (lp, rp), Conj (Neg rn, Neg ln))
  | x -> x;;

let rec fvt sf = function
    V x -> Im.add x () sf
  | A(f,l) -> List.fold_left fvt sf l;;
let rec fv sf = function
    Forall (i, t) -> if Im.mem i sf then fv sf t else Im.remove i (fv sf t)
  | Exists (i, t) -> if Im.mem i sf then fv sf t else Im.remove i (fv sf t)
  | Conj (l, r) -> fv (fv sf r) l
  | Disj (l, r) -> fv (fv sf r) l
  | Neg t -> fv sf t
  | Atom (_, t) -> List.fold_left fvt sf t
  | Eqiv (l, r) -> fv (fv sf r) l;;

let de_form = function
  | Cnf.Neg (Cnf.Atom (n, l)) -> -n, l
  | Cnf.Atom (n, l) -> n, l
  | _ -> failwith "de_form";;
let rec strip_disj sf = function
    Disj (l, r) -> strip_disj (strip_disj sf r) l
  | x -> x :: sf;;
let rec cnf_strip_disj sf = function
    Disj (l, r) -> cnf_strip_disj (cnf_strip_disj sf r) l
  | x -> de_form x :: sf;;

let rec strip_conj sf = function
    Conj (l, r) -> strip_conj (strip_conj sf r) l
  | x -> x :: sf;;

let rec miniscope = function
    Forall(x,Conj(l,r)) -> Conj(miniscope(Forall(x,l)),miniscope(Forall(x,r)))
  | Exists(x,Disj(l,r)) -> Disj(miniscope(Exists(x,l)),miniscope(Exists(x,r)))
  | Forall(x, t) -> if Im.mem x (fv Im.empty t) then Forall (x, miniscope t) else miniscope t
  | Exists(x, t) -> if Im.mem x (fv Im.empty t) then Exists (x, miniscope t) else miniscope t
(* Both of these are worse in practice *)
(*| Forall(x,(Disj _ as t)) ->
      (match List.partition (fun t -> Im.mem x (fv Im.empty t)) (strip_disj [] t) with
      | [], l -> list_disj (List.map miniscope l)
      | l, [] -> Forall (x, list_disj (List.map miniscope l))
      | l1, l2 -> Disj (Forall (x, list_disj (List.map miniscope l1)), list_disj (List.map miniscope l2)))*)
(*| Exists(x,(Conj _ as t)) ->
      (match List.partition (fun t -> Im.mem x (fv Im.empty t)) (strip_conj [] t) with
      | [], l -> list_conj (List.map miniscope l)
      | l, [] -> Exists (x, list_conj (List.map miniscope l))
      | l1, l2 -> Conj (Exists (x, list_conj (List.map miniscope l1)), list_conj (List.map miniscope l2)))*)
(*  | Forall(x,Disj(l,r)) ->
      if Im.mem x (fv Im.empty l) then if Im.mem x (fv Im.empty r) then
        Forall(x,Disj(miniscope l,miniscope r)) else Disj(Forall(x,miniscope l),miniscope r)
        else Disj(miniscope l,Forall(x,miniscope r))*)
(*  | Exists(x,Conj(l,r)) ->
      if Im.mem x (fv Im.empty l) then if Im.mem x (fv Im.empty r) then
        Exists(x,Conj(miniscope l,miniscope r)) else Conj(Exists(x,miniscope l),miniscope r)
        else Conj(miniscope l,Exists(x,miniscope r))*)
  | Neg p -> Neg(miniscope p)
  | Conj(l,r) -> Conj(miniscope l,miniscope r)
  | Disj(l,r) -> Disj(miniscope l,miniscope r)
  | x -> x;;
let miniscope t = let n = miniscope t in if n = t then t else miniscope n;;

(* Unbound variables are renamed to negative *)
let rec rename_term map = function
    V i -> V (try Im.find i map with Not_found -> -i)
  | A (i, l) -> A (i, List.map (rename_term map) l);;

let rec rename_form map mv = function
    Atom (i, t) -> mv, Atom (i, List.map (rename_term map) t)
  | Neg t -> let (mv, t) = rename_form map mv t in mv, Neg t
  | Conj (l, r) -> let mv, l = rename_form map mv l in let mv, r = rename_form map mv r in mv, Conj(l, r)
  | Disj (l, r) -> let mv, l = rename_form map mv l in let mv, r = rename_form map mv r in mv, Disj(l, r)
  | Forall (i, t) -> let nmv, t = rename_form (Im.add i mv map) (mv + 1) t in nmv, Forall (mv, t)
  | Exists (i, t) -> let nmv, t = rename_form (Im.add i mv map) (mv + 1) t in nmv, Exists (mv, t)
  | Eqiv _ -> invalid_arg "rename_form";;

let rename_form x = snd (rename_form Im.empty 0 x);;

let rec nnf = function
    Neg (Neg t) -> nnf t
  | Neg (Forall (i, t)) -> Exists (i, nnf (Neg t))
  | Neg (Exists (i, t)) -> Forall (i, nnf (Neg t))
  | Neg (Conj (l, r)) -> Disj (nnf (Neg l), nnf (Neg r))
  | Neg (Disj (l, r)) -> Conj (nnf (Neg l), nnf (Neg r))
  | Forall (i, t) -> Forall (i, nnf t)
  | Exists (i, t) -> Exists (i, nnf t)
  | Conj (l, r) -> Conj (nnf l, nnf r)
  | Disj (l, r) -> Disj (nnf l, nnf r)
  | t -> t;;


open Format;;
let pp_print_var f i =
  pp_print_char f (Char.chr (65 + i mod 26)); if i > 25 then pp_print_int f (i / 26);;

let rec pp_iter f fn sep = function
    [] -> ()
  | [e] -> fn f e
  | h :: t -> fn f h; pp_print_string f sep; pp_iter f fn sep t;;

let rec pp_print_term f = function
    V i -> pp_print_var f i
  | A (i, l) ->
      pp_print_string f (try Hashtbl.find no_cnst i with Not_found -> failwith ("pp_print_term: " ^ string_of_int i));
      if l <> [] then begin pp_print_char f '('; pp_iter f pp_print_term "," l; pp_print_char f ')' end;;

let pp_print_lit f (i, l) =
  match (i, l) with
    | (i, [l1; l2]) when i = eqn ->
(*       let l1, l2 = if l2 > l1 then l2, l1 else l1, l2 in*)
       pp_print_term f l1; pp_print_string f "="; pp_print_term f l2
    | (i, [l1; l2]) when i = -eqn ->
(*       let l1, l2 = if l2 > l1 then l2, l1 else l1, l2 in*)
       pp_print_term f l1; pp_print_string f "!="; pp_print_term f l2
    | _ ->
        if i < 0 then pp_print_char f '~';
        let s = try Hashtbl.find no_cnst (abs i) with Not_found -> failwith ("pp_print_lit: " ^ string_of_int i) in
        pp_print_string f s;
        if l <> [] then begin pp_print_char f '('; pp_iter f pp_print_term "," l; pp_print_char f ')' end;;

let pp_print_clause f cl = pp_print_char f '['; pp_iter f pp_print_lit "," cl; pp_print_char f ']';;
let pp_print_clause_tstp f cl = pp_print_char f '('; pp_iter f pp_print_lit "|" cl; pp_print_char f ')';;

let rec pp_print_form f = function
    Atom l -> pp_print_lit f l
  | Neg (Atom l) -> pp_print_string f "~"; pp_print_lit f l
  | Neg t -> pp_print_string f "~("; pp_print_form f t; pp_print_char f ')'
  | Conj (l, r) -> pp_print_char f '('; pp_print_form f l; pp_print_string f "&"; pp_print_form f r; pp_print_char f ')'
  | Disj (Neg l, r) -> pp_print_char f '('; pp_print_form f l; pp_print_string f "=>"; pp_print_form f r; pp_print_char f ')'
  | Disj (l, r) -> pp_print_char f '('; pp_print_form f l; pp_print_string f "|"; pp_print_form f r; pp_print_char f ')'
  | Forall (v, t) -> pp_print_string f "!["; pp_print_var f v; pp_print_string f "]:"; pp_print_form f t
  | Exists (v, t) -> pp_print_string f "?["; pp_print_var f v; pp_print_string f "]:"; pp_print_form f t
  | Eqiv (l, r) -> pp_print_char f '('; pp_print_form f l; pp_print_string f "<=>"; pp_print_form f r; pp_print_char f ')'
;;

let pp_print_path f cl = pp_print_char f '['; pp_iter f pp_print_form "," cl; pp_print_char f ']';;

let print_to_string printer =
  let buf = Buffer.create 10 in
  let fmt = formatter_of_buffer buf in
  pp_set_max_boxes fmt 1000;
  fun x -> printer fmt x; pp_print_flush fmt (); let s = Buffer.contents buf in Buffer.reset buf; s;;

let string_of_lit = print_to_string pp_print_lit;;
let string_of_form = print_to_string pp_print_form;;
let string_of_clause = print_to_string pp_print_clause;;
let string_of_clause_tstp = print_to_string pp_print_clause_tstp;;

let print_clause = pp_print_clause std_formatter;;

let rec skolem_tm map = function
    A (i, tm) -> A (i, List.map (skolem_tm map) tm)
  | V i -> try Im.find i map with Not_found -> V i;;

let drop_apos =
  let apos_rxp = Str.regexp "'" in
  fun s -> Str.global_replace apos_rxp "" s;;

(* This variant works without the Str module *)
(*
let drop_apos s =
  if not (String.contains s '\'') then s else begin
  let n = ref 0 in
  for i = 0 to String.length s - 1 do
    if String.unsafe_get s i <> '\'' then incr n
  done;
  let s' = Bytes.create !n in
  n := 0;
  for i = 0 to String.length s - 1 do
    let c = String.unsafe_get s i in
    if c <> '\'' then (Bytes.unsafe_set s' !n c; incr n)
  done;
  Bytes.to_string s'
  end
;;*)


let skolem_no = ref 0;;
let skolem tm =
  if !content_names then skolem_no := 0;
  let rec skolem ((map, uv) as sf) = function
      Forall (i, t) -> Forall (i, skolem (map, i :: uv) t)
    | Conj (l, r) -> Conj (skolem sf l, skolem sf r)
    | Disj (l, r) -> Disj (skolem sf l, skolem sf r)
    | (Exists (i, t) as tm) ->
        let outer = List.map (fun x -> V x) uv in
        let uvs = List.map (print_to_string pp_print_var) uv in
        let sk_no = incr skolem_no; const_number (
          if !content_names then "'skolem(" ^ (drop_apos (string_of_form tm)) ^ "-" ^ String.concat "-" uvs ^ ")'" else "sk" ^ string_of_int !skolem_no) in
        skolem (Im.add i (A (sk_no, outer)) map, uv) t
    | Atom (p, tm) -> Atom (p, List.map (skolem_tm map) tm)
    | Neg x -> Neg (skolem sf x)
    | Eqiv _ -> invalid_arg "skolem" in
  skolem (Im.empty, []) tm;;

(* Expects skolemized nnf *)
let rec noforall = function
    Forall (i, t) -> noforall t
  | Conj (l, r) -> Conj (noforall l, noforall r)
  | Disj (l, r) -> Disj (noforall l, noforall r)
  | x -> x;;

(* Expectss nnf with no quantifiers *)
let rec cnf = function
  | Disj (l, r) -> (match (cnf l, cnf r) with
    | Conj (ll, lr), r -> Conj (cnf (Disj (ll, r)), cnf (Disj (lr, r)))
    | l, Conj (rl, rr) -> Conj (cnf (Disj (l, rl)), cnf (Disj (l, rr)))
    | x, y -> Disj (x, y)
  )
  | Conj (l, r) -> Conj (cnf l, cnf r)
  | x -> x
;;

let rec rev_strip_disj sf = function
    Disj (l, r) -> rev_strip_disj (rev_strip_disj sf l) r
  | x -> x :: sf;;
let rec rev_strip_conj sf = function
    Conj (l, r) -> rev_strip_conj (rev_strip_conj sf l) r
  | x -> x :: sf;;

(* TODO: Look at: *)
(* P. Jackson, D. Sheridan. Clause Form Conversions for Boolean Circuits *)
(* P. Manolios, D. Vroon. Efficient Circuit to CNF Conversion *)
let defno = ref 0;;
let rec dcnf sf = function
  | Conj (l, r) -> dcnf (dcnf sf l) r
  | (Disj _ as d) ->
      let l = rev_strip_disj [] d in
      let (sf, ret) = List.fold_left dcnf_disj (sf, []) l in ret :: sf
  | Atom l -> [l] :: sf
  | Neg (Atom (i, p)) -> [-i, p] :: sf
  | _ -> failwith "dcnf"
and dcnf_disj (sfc, sfd) = function
  | (Conj _ as c) ->
      let l = rev_strip_conj [] c in
      let (sfc, l) = List.fold_left ccnf_disj (sfc, []) l in
      let l = List.sort compare (List.map (List.sort compare) l) in
      let n = const_number (if !content_names then
        "'def(" ^ (drop_apos (String.concat "&" (List.map string_of_clause l))) ^ ")'" else (incr defno; "def" ^ string_of_int !defno)) in
      let fvm = List.fold_left (List.fold_left (fun sf (_, l) -> List.fold_left fvt sf l)) Im.empty l in
      let fvs = Im.fold (fun k _ sf -> V k :: sf) fvm [] in
      let pos = n, fvs and neg = -n, fvs in
      (List.fold_left (fun sf d -> (neg :: d) :: sf) sfc l, pos :: sfd)
  | Atom l -> (sfc, l :: sfd)
  | Neg (Atom (i, p)) -> (sfc, (-i, p) :: sfd)
  | _ -> failwith "dcnf_disj"
and ccnf_disj (sfc, sfd) = function
  | (Disj _ as d) ->
      let l = rev_strip_disj [] d in
      let (sfc, d) = List.fold_left dcnf_disj (sfc, []) l in (sfc, d :: sfd)
  | Atom l -> (sfc, [l] :: sfd)
  | Neg (Atom (i, p)) -> (sfc, [-i, p] :: sfd)
  | _ -> failwith "ccnf_disj"
;;

let rec cnf_size = function
  | Conj (l, r) | Disj (l, r) -> 1 + cnf_size l + cnf_size r
  | _ -> 1;;

(*let rec cnf_upto n = function
  | Disj (l, r) -> (match (cnf_upto n l, cnf_upto n r) with
    | (Conj (ll, lr) as l), r ->
        if cnf_size l < n && cnf_size r < n then
 Conj (cnf (Disj (ll, r)), cnf (Disj (lr, r)))
    | l, (Conj (rl, rr) as r) -> Conj (cnf (Disj (l, rl)), cnf (Disj (l, rr)))
    | x, y -> Disj (x, y)
  )
  | Conj (l, r) -> Conj (cnf_upto n l, cnf_upto n r)
  | x -> x
;;*)


let rec collect_f f = function
    A (i, t) -> List.fold_left collect_f (if t <> [] then Im.add i (List.length t) f else f) t
  | _ -> f;;

let rec collect_fp ((f, p) as sf) = function
    Neg x -> collect_fp sf x
  | Conj (l, r) -> collect_fp (collect_fp sf l) r
  | Disj (l, r) -> collect_fp (collect_fp sf l) r
  | Forall (i, t) -> collect_fp sf t
  | Exists (i, t) -> collect_fp sf t
  | Atom (i, t) -> (List.fold_left collect_f f t, if t <> [] then Im.add (abs i) (List.length t) p else p)
  | Eqiv (l, r) -> collect_fp (collect_fp sf l) r;;

let rec list_forall vs t = List.fold_right (fun x sf -> Forall(x, sf)) vs t;;

let funpred_axiom isfun p arity =
  let even = Array.to_list (Array.init arity (fun i -> 2 * i)) in let odd = List.map (fun x -> x + 1) even in
  let ovar = List.map (fun x -> V (x + 1)) even and evar = List.map (fun x -> V x) even in
  let eqs =
    if isfun then List.rev (List.map2 (fun x y -> Atom(eqn, [x; y])) evar ovar)
    else List.rev (List.map2 (fun x y -> Atom(eqn, [x; y])) ovar evar) in
  list_forall even (list_forall odd (List.fold_left (fun sf eq -> Disj (Neg eq, sf)) (
    if isfun then (Atom (eqn, [A (p, evar); A (p, ovar)])) else
    Disj (Neg (Atom (p, evar)), Atom (p, ovar))
  ) eqs));;

let eq_refl = Forall (1, Atom (eqn, [V 1; V 1]));;
let eq_sym = Forall (1, Forall (2, Disj (Neg (Atom (eqn, [V 1; V 2])), Atom (eqn, [V 2; V 1]))));;
let eq_trans = Forall (1, Forall (2, Forall (3, Disj (Neg (Conj (Atom (eqn, [V 2; V 3]), Atom (eqn, [V 1; V 2]))), Atom (eqn, [V 1; V 3])))));;

let equal_axioms forms =
  let fnct, pred = List.fold_left collect_fp (Im.empty, Im.empty) forms in
  if not (Im.mem eqn pred) then forms else
  let pred = Im.remove eqn pred in
  let s = eq_trans :: eq_sym :: eq_refl :: forms in
  let s1 = Im.fold (fun p a sf -> funpred_axiom false p a :: sf) pred s in
  Im.fold (fun f a sf -> funpred_axiom true f a :: sf) fnct s1;;


let fold_map f sf l =
  let (sf, rev) = List.fold_left (fun (sf, res) e -> let (sf, nr) = f sf e in sf, nr :: res) (sf, []) l in sf, List.rev rev;;

let rec rename_unbound_term ((map, next) as sf) = function
    V i -> (try (sf, V (Im.find i map)) with Not_found -> ((Im.add i next map, next + 1), V next))
  | A (i, l) -> let sf, l = fold_map rename_unbound_term sf l in sf, A (i, l)

let rename_unbound_lit sf (i, l) = let sf, l = fold_map rename_unbound_term sf l in (sf, (i, l));;
let rename_unbound_clause l = let ((_, maxv), cl) = fold_map rename_unbound_lit (Im.empty, 0) l in (cl, maxv);;

let rec rename_unbound sf = function
    Atom (i, l) -> let sf, l = fold_map rename_unbound_term sf l in sf, Atom (i, l)
  | Neg t -> let (sf, t) = rename_unbound sf t in sf, Neg t
  | Disj (l, r) -> let sf, l = rename_unbound sf l in let sf, r = rename_unbound sf r in sf, Disj(l, r)
  | _ -> failwith "rename unbound";;

let rename_unbound x = snd (rename_unbound (Im.empty, 0) x);;

let rec matrix sf = function
  | Conj (l, r) -> matrix (matrix sf r) l
  | x -> mat_elem [] (rename_unbound x) :: sf
and mat_elem sf = function
  | Disj (l, r) -> mat_elem (mat_elem sf r) l
  | Atom l -> l :: sf
  | Neg (Atom (i, p)) -> (-i, p) :: sf
  | _ -> failwith "matrix: not cnf!";;


(* Remove "a /\ a", remove clauses with "a" when no "~a", remove clause repetitions  *)

let rec uniq2 acc = function
  x::(y::_ as t) -> uniq2 (if x = y then acc else x :: acc) t
| [x] -> List.rev (x :: acc)
| [] -> List.rev acc;;
let lsetify l = uniq2 [] (List.sort compare l);;

let setify l =
  let h = Hashtbl.create (List.length l * 2) in
  List.rev (List.fold_left (fun sf x -> if Hashtbl.mem h x then sf else (Hashtbl.add h x (); x :: sf)) [] l);;

let hash = pred_number "'#'";;
let hasht = Atom(hash, []);;

(* This version has no hash filtering *)
let rec iter_rest acc fnctn = function
  [] -> ()
| h :: t -> fnctn h (List.rev_append acc t); iter_rest (h :: acc) fnctn t;;

(*
Costs more than helps.
let opt_mat m =
  let m = setify (List.map setify m) in
  let dt = ref Dtree.empty_dt in
  List.iter (iter_rest [] (fun (p, a) r -> dt := Dtree.insert r !dt [A (p, a)])) m;
  dt := Dtree.update_jl !dt;
  let rec process processed = function
    [] -> processed
  | cl1 :: clr ->
      let rec finish_rest lip = function
        [] -> process (cl1 :: processed) clr
      | ((n,a) as li1) :: lit -> let p = -n in
          if p = hash then process (cl1 :: processed) clr else
          match Dtree.unifs_nojl [] !dt [A (p,a)] with
            [] -> process processed clr
(*          | [h] -> ???*)
          | _ -> finish_rest (li1 :: lip) lit
      in finish_rest [] cl1
  in List.rev (process [] m)
;;
*)
