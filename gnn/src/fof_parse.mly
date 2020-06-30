%{
  open Cnf;;
%}

%token <string> Word
%token <string list> All
%token <string list> Ex
%token Eof Openp Closep Dot Comma Eq Neq Tilde Plus Eqvt Neqvt Impl Revimpl And Or
%right Impl
%nonassoc Eqvt
%nonassoc Eq Neq
%right Or
%left And
%nonassoc Tilde
%nonassoc All Exists

%start fof_top fof_data
%type <(string * string * Cnf.form)> fof_top
%type <(bool * ((int * Cnf.term list) * (int * Cnf.term list) list * Cnf.form list * (int * Cnf.term list) list * (int * Cnf.term list) * (int * Cnf.term list) list * Cnf.form list * (int * Cnf.term list) list * int list * (float * int * int * Cnf.form) list))> fof_data
%%

fof_top :
  Word Openp Word Comma Word Comma formula Closep Dot { ($3, $5, $7) }
| Eof { raise End_of_file };

formula :
| qformula     { $1 }
| formula Impl formula { Disj (Neg $1, $3) }
| formula Revimpl formula { Disj (Neg $3, $1) }
| formula Eqvt formula  { Eqiv ($1, $3) }
| formula And formula { Conj ($1, $3) }
| formula Or formula { Disj ($1, $3) }
| formula Neqvt formula { Neg (Eqiv ($1, $3)) }

qformula :
  Word { pred $1 [] }
| Word Openp ts { pred $1 $3 }
| fterm Eq fterm { Atom (eqn, [$1; $3]) }
| fterm Neq fterm { Neg (Atom (eqn, [$1; $3])) }
| Tilde qformula { Neg $2 }
| All qformula { list_forall $1 $2 }
| Ex qformula { list_exists $1 $2 }
| Openp formula Closep { $2 }

fterm :
  Word { if is_uppercase $1 then V (var $1) else const $1 [] }
| Word Openp ts { const $1 $3 }

ts :
  fterm Comma ts { $1 :: $3 }
| fterm Closep   { [$1] };

flist :
  formula Comma flist  { $1 :: $3 }
| formula Closep { [$1] }
| Closep { [] };

valf :
  Openp Word Comma Word Comma Word Comma formula Closep  { float_of_string $2, int_of_string $4, int_of_string $6, $8 }

valflist :
  valf Comma valflist  { $1 :: $3 }
| valf Closep { [$1] }
| Closep { [] };

intlist :
  Word Comma intlist  { int_of_string $1 :: $3 }
| Word Closep { [int_of_string $1] }
| Closep { [] };

fof_entry:
          formula Comma Openp flist Comma Openp flist Comma Openp flist
    Comma Openp formula Closep Comma Openp flist Comma Openp flist Comma Openp flist
    Comma Openp intlist Comma Openp valflist
          Dot { (Fof.de_form $1, List.rev_map Fof.de_form $4, $7, List.rev_map Fof.de_form $10,
                 Fof.de_form $13, List.rev_map Fof.de_form $17, $20, List.rev_map Fof.de_form $23, $26, $29) }
| Eof { raise End_of_file };

fof_data2 :
          formula Comma Openp flist Comma Openp flist Comma Openp flist
    Comma Openp formula Closep Comma Openp flist Comma Openp flist Comma Openp flist
    Comma Openp intlist Comma Openp valflist
          Dot { (Fof.de_form $1, List.rev_map Fof.de_form $4, $7, List.rev_map Fof.de_form $10,
                 Fof.de_form $13, List.rev_map Fof.de_form $17, $20, List.rev_map Fof.de_form $23, $26, $29) }
| Eof { raise End_of_file };

fof_data :
| Plus fof_data2 {(true, $2)}
| Tilde fof_data2 {(false, $2)}
| Eof { raise End_of_file };

