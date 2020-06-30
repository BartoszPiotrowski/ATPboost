open Cnf;;
open Fof;;
open Fof_parse;;

let unifyskolems = ref false;;
let fea_pat_len = ref 2;; (* 0 = only current, 1 = one more element, ... *)

let fea_cross = ref false;;
let fea_undersubst = ref true;;  (* Check variables in the substitution when computing features *)

let fea_model = ref false;;
let fea_nocount = ref false;;

let read_file fname =
  let ic = open_in fname in
  let rxp = Str.regexp " " in
  let ret = ref [] in
  try while true do
    ret := Str.split rxp (input_line ic) :: !ret
  done; assert false with End_of_file -> close_in ic; List.rev !ret;;

let read_model_fea fean mapn =
  if !fea_model = false then fun _ -> [] else begin
    let hash1 = Hashtbl.create 10 and hash2 = Hashtbl.create 10 in
    let f1 = function h :: t -> Hashtbl.add hash1 h (List.map md5s t) | _ -> failwith "wrong model features" in
    let f2 = function [l; r] -> Hashtbl.add hash2 (int_of_string l) r | _ -> failwith "wrong mapping" in
    List.iter f1 (read_file fean);
    List.iter f2 (read_file mapn);
    fun cno -> try Hashtbl.find hash1 (Hashtbl.find hash2 cno) with Not_found -> []
  end;;

let features_modulo = 262139;; (* prime 2 ^ 18 - 5 *)
let fmod n = 1 + let r = n mod features_modulo in if r < 0 then r + features_modulo else r;;
let fmod3 n = 1 + let r = n mod (features_modulo * 3) in if r < 0 then r + (features_modulo * 3) else r;;

let fea_vconst = 17;;
let rec bit_features_cont last sf = function
  | V _ -> last * fea_vconst :: fea_vconst :: sf
  | A (f, l) -> List.fold_left (bit_features_cont f) (last * f :: f :: sf) l;;
let bit_features sf (n, l) = List.fold_left (bit_features_cont n) (n :: sf) l;;

let imincr1 key sf =
  let key = fmod key in
  try let ov = Im.find key sf in
      Im.add key (ov + 1) sf
  with Not_found -> Im.add key 1 sf;;

let fmodi n i = 1 + let r = n mod i in if r < 0 then r + i else r;;

(* Bloom filters *)
let imincr2 key sf =
  let key1 = fmodi key 131071 in
  let key2 = fmodi key 131063 + 131071 in
  let sf1 = try let ov = Im.find key1 sf in Im.add key1 (ov + 1) sf
            with Not_found -> Im.add key1 1 sf in
  let sf2 = try let ov = Im.find key2 sf1 in Im.add key2 (ov + 1) sf1
            with Not_found -> Im.add key2 1 sf1 in
  sf2;;

let imincr3 key sf =
  let key1 = fmod key in
  let key2 = fmod (key * 81001) in
  let sf1 = try let ov = Im.find key1 sf in Im.add key1 (ov + 1) sf
            with Not_found -> Im.add key1 1 sf in
  let sf2 = try let ov = Im.find key2 sf1 in Im.add key2 (ov + 1) sf1
            with Not_found -> Im.add key2 1 sf1 in
  sf2;;

let imincr = imincr1;;

let simpf i =
  if not !unifyskolems then i else
  let s = Hashtbl.find no_cnst i in
  if String.length s > 3 && s.[0]='\'' && s.[1]='s' && s.[2]='k' then
    (features_modulo / 2) else i;;

(*
let threefea = ref true;;

let rec ubit2_cont2 s butlast last sf = function
  | V n ->
     (match if !fea_undersubst then subst_get s n else None with
       None -> imincr (7 * butlast + 5 * last + fea_vconst) (imincr (5 * last + fea_vconst) (imincr fea_vconst sf))
     | Some t -> ubit2_cont2 s butlast last sf t)
  | A (f, l) ->
     let f = simpf f in
     List.fold_left (ubit2_cont2 s last f) (imincr (7 * butlast + 5 * last + f) (imincr (5 * last + f) (imincr f sf))) l;;

let rec ubit2_cont1 s last sf = function
  | V n ->
     (match if !fea_undersubst then subst_get s n else None with 
       None -> imincr (5 * last + fea_vconst) (imincr fea_vconst sf)
     | Some t -> ubit2_cont1 s last sf t)
  | A (f, l) ->
     let f = simpf f in
     List.fold_left (ubit2_cont2 s last f) (imincr (5 * last + f) (imincr f sf)) l;;

let rec ubit2_cont s last sf = function
  | V n ->
     (match if !fea_undersubst then subst_get s n else None with 
       None -> imincr (5 * last + fea_vconst) (imincr fea_vconst sf)
     | Some t -> ubit2_cont s last sf t)
  | A (f, l) ->
     let f = simpf f in
     List.fold_left (ubit2_cont s f) (imincr (5 * last + f) (imincr f sf)) l;;
let ubit2 s sf (n, l) = List.fold_left ((if !threefea then ubit2_cont1 else ubit2_cont) s n) (imincr n sf) l;;
 *)

let fea_prime = 1933;;
(* adds:  v   v + p*a   v + p*a + p*p*b   ... *)
let rec ubitn_add current prime sf len = function
  | [] -> imincr current sf
  | h :: t ->
     if len <= 0 then imincr current sf else
     ubitn_add (current * prime + h) (prime * fea_prime) (imincr current sf) (len - 1) t;;
let rec ubitn_cont s lasts sf = function
  | V n ->
     (match if !fea_undersubst then subst_get s n else None with
       None -> ubitn_add fea_vconst fea_prime sf !fea_pat_len lasts
     | Some t -> ubitn_cont s lasts sf t)
  | A (f, l) ->
     let f = simpf f in
     List.fold_left (ubitn_cont s (f :: lasts)) (ubitn_add f fea_prime sf !fea_pat_len lasts) l;;
let ubit2 s sf (n, l) = List.fold_left (ubitn_cont s [n]) (imincr n sf) l;;

let unpack_im im =
  if !fea_nocount then List.rev (Im.fold (fun i n sf -> (i, 1) :: sf) im [])
  else List.rev (Im.fold (fun i n sf -> (i, n) :: sf) im []);;
let ubit2_list s start l =
  let im = List.fold_left (fun sf v -> Im.add (fmod v) 1 sf) Im.empty start in
  unpack_im (List.fold_left (ubit2 s) im l);;

let cross l1 l2 =
  let im = List.fold_left (fun sf (e, n) -> Im.add e n sf) Im.empty l1 in
  let im = List.fold_left (fun sf (e, m) -> Im.add e m sf) im l2 in
  let im_add k v mp = try Im.add k (v + Im.find k mp) mp with Not_found -> Im.add k v mp in
  let im =
    List.fold_left (fun sf (l1e, n) ->
      List.fold_left (fun sf (l2e, m) ->
        im_add (fmod3 (199 * l1e + l2e)) (m * n) sf) sf l2) im l1 in
  unpack_im im;;

let rec update_freq_tm s im = function
  | V n -> (match subst_get s n with None -> im | Some t -> update_freq_tm s im t)
  | A (f, l) ->
     let im2 = try let ov = Im.find f im in Im.add f (ov + 1) im with Not_found -> Im.add f 1 im in
     List.fold_left (update_freq_tm s) im2 l;;
let update_freq_lit s im (_, ts) = List.fold_left (update_freq_tm s) im ts;;

let most_common im =
  let (mk1, mv1) = Im.fold (fun k v (mk, mv) -> if v > mv then (k, v) else (mk, mv)) im (0, 0) in
  let (mk2, mv2) = Im.fold (fun k v (mk, mv) -> if v > mv && k <> mk1 then (k, v) else (mk, mv)) im (0, 0) in
  ((mk1, mv1), (mk2, mv2));;

let rec holstep_t sf = function
  | V i -> (1 + features_modulo + i) :: sf
  | A (p, args) ->
     let sf1 = List.rev_append (Array.to_list (Array.make (List.length args) 0)) sf in
     let sf2 = (1 + fmod p) :: sf1 in
     List.fold_left holstep_t sf2 args;;

let holstep_p (p, args) = List.rev (holstep_t [] (A (p, args)));;
let holstep_list l = List.concat (List.map holstep_p l);;

let contr_no = Hashtbl.create 100
and no_contrstr = Hashtbl.create 100;;
let rec find_free_contr n = if Hashtbl.mem no_contrstr n then find_free_contr (n + 1) else n;;
let no_contrfea = Hashtbl.create 100;;
let no_contrholstep = Hashtbl.create 100;;
let no_contrvars = Hashtbl.create 100;;

let contr_number get_model_fea contr strofcontr =
  try Hashtbl.find contr_no strofcontr with Not_found ->
    let cno = find_free_contr (md5s strofcontr) in
    let start = if !fea_model then cno :: get_model_fea cno else [cno] in
    Hashtbl.add no_contrfea cno (List.map (fun (x, n) -> (x + 2 * features_modulo, n)) (ubit2_list empty_sub start contr));
    Hashtbl.add no_contrholstep cno (holstep_list contr);
    Hashtbl.add no_contrvars cno (Im.cardinal (List.fold_left (lit_vars Im.empty) Im.empty contr));
    Hashtbl.add contr_no strofcontr cno;
    Hashtbl.add no_contrstr cno strofcontr; cno;;
let neg_atom_of_lit ((p, l) as a) = if p > 0 then Neg (Atom a) else Atom (-p, l);;
let atom_of_lit ((p, l) as a) = if p > 0 then Atom a else Neg (Atom (-p, l));;
let string_of_contr lit rest =
  string_of_form (rename_unbound (List.fold_right (fun a b ->
    Disj ((*neg_*)atom_of_lit a, b)) (List.sort compare rest) (atom_of_lit lit)));;

let str_of_fea n = try Hashtbl.find no_cnst n with Not_found -> "~" ^ Hashtbl.find no_cnst (-n);;

module Fm = Map.Make(struct type t = (int * term list) let compare = compare end);;

let rec normalize_var = function
  | V n -> V 0
  | A (p, l) -> A (p, List.map normalize_var l);;

let normalize l =
  let sum = List.fold_left (+.) 0. l in
  List.map (fun v -> v /. sum) l;;

