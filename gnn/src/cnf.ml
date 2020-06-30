type term = V of int
          | A of int * term list;;
type lit = int * term list;;
type form = Atom of (int * term list)
          | Neg of form
          | Conj of form * form
          | Disj of form * form
          | Forall of int * form
          | Exists of int * form
          | Eqiv of form * form;;

exception Unify;;

(* Substitutions are maps from int to term *)
module Im = Map.Make(struct type t = int let compare = compare end);;

let rec istriv env x = function
    V y -> y = x || (try istriv env x (Im.find y env) with Not_found -> false)
  | A (f, a) -> List.exists (istriv env x) a && raise Unify;;

let rec unify env tm1 tm2 = match tm1,tm2 with
    A(f,fargs),A(g,gargs) ->
      if f <> g then raise Unify else
        List.fold_left2 unify env fargs gargs
  | _,V(x) ->
     (try unify env tm1 (Im.find x env)
     with Not_found -> if istriv env x tm1 then env else Im.add x tm1 env)
  | V(x),_ ->
     try unify env (Im.find x env) tm2
     with Not_found -> if istriv env x tm2 then env else Im.add x tm2 env;;

let unify_list env l1 l2 = List.fold_left2 unify env l1 l2;;

let unify_lit env ((h1 : int), l1) (h2, l2) =
  if h1 <> h2 then raise Unify else List.fold_left2 unify env l1 l2;;

let rec bump_small off tm = match tm with
    V v -> V(v + off)
  | A(f, a) -> A(f, List.map (bump_small off) a);;

(* Unification with renaming of the second argument *)
let rec unify_rename off_l off_r ((env, (nv1, nv2)) as sf) tm1 tm2 = match tm1,tm2 with
    A(f,fargs),A(g,gargs) ->
      if f <> g then raise Unify else
        List.fold_left2 (unify_rename off_l off_r) sf fargs gargs
  | _,V(x) -> let x = x + off_r in
     (try unify_rename off_l 0 sf tm1 (Im.find x env)
     with Not_found -> if istriv env x tm1 then sf
                       else (Im.add x tm1 env, if x < off_l then ((x,tm1) :: nv1, nv2) else (nv1, (x,tm1) :: nv2)))
  | V(x),_ ->
     try unify_rename off_l off_r sf (Im.find x env) tm2
     with Not_found ->
       let tm2' = bump_small off_r tm2 in
       if istriv env x tm2' then sf else (Im.add x tm2' env, if x < off_l then ((x,tm2')::nv1, nv2) else (nv1, (x,tm2')::nv2));;

let rec eq2 env x = function
    V y -> y = x || (try eq2 env x (Im.find y env) with Not_found -> false)
  | A (f, a) -> false;;

let rec eq env tm1 tm2 =
  tm1 == tm2 ||
  match tm1,tm2 with
    A(f,fargs),A(g,gargs) -> f = g && List.for_all2 (eq env) fargs gargs
  | _,V(x) ->
    (try eq env tm1 (Im.find x env)
     with Not_found -> eq2 env x tm1)
  | V(x),_ ->
    (try eq env (Im.find x env) tm2
     with Not_found -> eq2 env x tm2);;

let eq_lit env (p1,args1) (p2,args2) =
  p1 = p2 && List.for_all2 (eq env) args1 args2;;

(* Only for printing *)
let rec inst_tm env tm = match tm with
    V(v) -> (try inst_tm env (Im.find v env) with Not_found -> tm)
  | A(f,args) -> A(f,List.map (inst_tm env) args);;
let inst_lit env (p, l) = (p, List.map (inst_tm env) l);;
let subst_get s v = try Some (Im.find v s) with Not_found -> None

let rec bump_vars off = function
    V x -> V (x + off)
  | A (x, l) -> A (x, List.map (bump_vars off) l);;

let rec subst_vars list = function
    V x -> (try subst_vars list (List.assoc x list) with Not_found -> V x)
  | A (x, l) -> A (x, List.map (subst_vars list) l);;

let rec bump_subst_vars off list = function
    V x -> subst_vars list (V (x + off))
  | A (x, l) -> A (x, List.map (bump_subst_vars off list) l);;

let unify_rename_subst off l1 l2 sub list =
  let (s, (nv1, nv2)) = List.fold_left2 (unify_rename off off) (sub, ([], [])) l1 l2 in
  match nv1, nv2 with
    [], [] -> (sub, List.map (fun (p,l) -> (p,List.map (bump_vars off) l)) list)
  | [], _  -> (sub, List.map (fun (p,l) -> (p,List.map (bump_subst_vars off nv2) l)) list)
  | _ , [] -> (s,   List.map (fun (p,l) -> (p,List.map (bump_vars off) l)) list)
  | _ , _  ->
     (List.fold_left (fun sf (v,t) -> Im.add v (subst_vars nv2 t) sf) sub nv1,
     List.map (fun (p,l) -> (p,List.map (bump_subst_vars off nv2) l)) list)

let empty_sub = Im.empty;;

let md5s s = Int64.to_int ((Obj.magic (Digest.to_hex (Digest.string s))) : int64);;

let cnst_no, no_cnst = Hashtbl.create 100, Hashtbl.create 100;;

let rec find_free_const n = if Hashtbl.mem no_cnst n then find_free_const (n + 1) else n;;
let rec find_free_pred n =
  if Hashtbl.mem no_cnst n || Hashtbl.mem no_cnst (-n) then
    find_free_pred (if n + 1 < 0 then 1 else n + 1) else n;;

let const_number name =
  try Hashtbl.find cnst_no name with Not_found ->
    let cno = find_free_pred (abs (md5s name)) in
    Hashtbl.add cnst_no name cno; Hashtbl.add no_cnst cno name; cno;;

let pred_number name =
  try Hashtbl.find cnst_no name with Not_found ->
    let pno = find_free_pred (abs (md5s name)) in
    Hashtbl.add cnst_no name pno; Hashtbl.add no_cnst pno name; pno;;

let const name args = A (const_number name, args);;
let pred name args = Atom (pred_number name, args);;

let var_no, no_var, var_num = Hashtbl.create 100, Hashtbl.create 100, ref 0;;

let var (name : string) =
  try Hashtbl.find var_no name with Not_found ->
    incr var_num; Hashtbl.add var_no name !var_num; Hashtbl.add no_var !var_num name; !var_num;;

let eqn = pred_number "=";;

let list_forall vs t = List.fold_right (fun v sf -> Forall (var v, sf)) vs t;;
let list_exists vs t = List.fold_right (fun v sf -> Exists (var v, sf)) vs t;;
let list_conj = function [] -> invalid_arg "list_conj"
  | h :: t -> List.fold_left (fun sf e -> Conj (sf, e)) h t;;
let list_disj = function [] -> invalid_arg "list_disj"
  | h :: t -> List.fold_left (fun sf e -> Disj (sf, e)) h t;;
let is_uppercase s = s <> "" && s.[0] <> Char.lowercase s.[0];;

let rec term_size env sf = function
  | A(f,fargs) -> List.fold_left (term_size env) (sf + 1) fargs
  | V(x) -> try term_size env sf (Im.find x env) with Not_found -> sf + 1;;

let lit_size env sf (_, ts) = List.fold_left (term_size env) sf ts;;

let rec term_depth env = function
  | A(f,fargs) -> 1 + List.fold_left (fun sf t -> max sf (term_depth env t)) 0 fargs
  | V(x) -> try term_depth env (Im.find x env) with Not_found -> 1;;
let lit_depth env (_, ts) = 1 + List.fold_left (fun sf t -> max sf (term_depth env t)) 0 ts;;

let rec term_vars env sf = function
  | A(f,fargs) -> List.fold_left (term_vars env) sf fargs
  | V(x) -> try term_vars env sf (Im.find x env) with Not_found ->
      try Im.add x (1 + Im.find x sf) sf with Not_found -> Im.add x 1 sf;;
let rec lit_vars env sf (_, ts) = List.fold_left (term_vars env) sf ts;;


