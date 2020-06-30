{
  open Cnf;;
  open Lexing;;
  open Fof_parse;;
}

let white = [' ' '\t' '\r' '\n']
let letter = ['/' 'a'-'z' 'A'-'Z' '0'-'9' '_' '-']
let letterdot = ['/' 'a'-'z' 'A'-'Z' '0'-'9' '_' '-' '.']
let any = [^ '\r' '\n']

rule hhlex = parse
| '%' any*           {hhlex lexbuf}
| '#' any*           {hhlex lexbuf}
| white+             {(*Printf.printf "w%!"; *)hhlex lexbuf}
| eof                {Eof}
| '('                {(*Printf.printf "(%!"; *)Openp}
| ')'                {(*Printf.printf ")%!"; *)Closep}
| '.'                {Dot}
| ','                {Comma}
| '!' white* '['     {(*Printf.printf "!%!"; *)All (lex_ids lexbuf)}
| '?' white* '['     {Ex (lex_ids lexbuf)}
| '='                {Eq}
| "!="               {Neq}
| '~'                {Tilde}
| '+'                {Plus}
| "<=>"              {Eqvt}
| "<~>"              {Neqvt}
| "=>"               {(*Printf.printf ">%!"; *)Impl}
| "<="               {(*Printf.printf ">%!"; *)Revimpl}
| '&'                {(*Printf.printf "&%!"; *)And}
| '|'                {Or}
| '$' letter+        {Word (Lexing.lexeme lexbuf)}
| letter letterdot*  {(*Printf.printf "w%!"; *)let s = Lexing.lexeme lexbuf in Word (if s = "#" then "'#'" else s) }
| '\''               {Word ("'" ^ lex_squot lexbuf ^ "'")}
| '"'                {Word ("\"" ^ lex_dquot lexbuf ^ "\"")}

and lex_squot = parse
| '\''               {""}
| '\\' '\\'          {"\\" ^ lex_squot lexbuf}
| '\\' '\''          {"'" ^ lex_squot lexbuf}
| [^ '\'' '\\']+     {let s = Lexing.lexeme lexbuf in s ^ lex_squot lexbuf}

and lex_dquot = parse
| '"'                {""}
| '\\' '\\'          {"\\" ^ lex_dquot lexbuf}
| '\\' '"'           {"\"" ^ lex_dquot lexbuf}
| [^ '"' '\\']+      {let s = Lexing.lexeme lexbuf in s ^ lex_dquot lexbuf}

and lex_ids = parse
| white+             {lex_ids lexbuf}
| letter+            {let i = Lexing.lexeme lexbuf in
                      i :: (lex_ids_more lexbuf)}

and lex_ids_more = parse
| white+             {lex_ids_more lexbuf}
| ','                {lex_ids lexbuf}
| ']' white* ':'     {[]}

{
let file fname =
  let inc = if fname = "-" then stdin else open_in fname in
  let lexb = Lexing.from_channel inc in
  let rec prf acc =
    try
      let v =
        try Fof_parse.fof_top hhlex lexb
        with Parsing.YYexit a -> Obj.magic a
      in
      prf (v :: acc)
    with End_of_file -> close_in inc; acc
  in
  prf [];;

let data_file fname =
  let inc = if fname = "-" then stdin else open_in fname in
  let lexb = Lexing.from_channel inc in
  let rec prf acc =
    match
      try Some (Fof_parse.fof_data hhlex lexb)
      with Parsing.YYexit a -> Some (Obj.magic a)
      | End_of_file -> None
    with
      Some v -> prf (v :: acc)
    | None -> close_in inc; acc
  in
  prf [];;

let problem fname =
  let fofs = file fname in
  let ths = List.map (fun (_,_,x) -> x) (List.filter (fun (_, x, _) -> x = "axiom" || x = "hypothesis" || x = "definition" || x = "lemma" || x = "theorem" || x = "plain") fofs) in
  match List.map (fun (_,_,x) -> x) (List.filter (fun (_, x, _) -> x = "conjecture") fofs) with
    h :: t -> (ths, List.fold_left (fun a b -> Disj (a, b)) h t)
  | _ ->
    match List.map (fun (_,_,x) -> x) (List.filter (fun (_, x, _) -> x = "negated_conjecture") fofs) with
      h :: t -> (ths, Neg (List.fold_left (fun a b -> Conj (a, b)) h t))
    | _ -> failwith "No conjecture or negated conjecture";;

}
