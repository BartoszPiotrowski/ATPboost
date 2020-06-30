open Circuit;;

let int_of_sgn b = if b then -1 else 1;;

let rec print_list = function
  | [] -> ()
  | [n] -> print_int n
  | n :: rest -> print_int n; print_char ' '; print_list rest;;


let rec print_node_input_acc symbol_acc node_acc sgn_acc = function
  | [] ->
      let symbol = List.rev symbol_acc
      and node = List.rev node_acc
      and sgn = List.rev sgn_acc in
      print_list symbol; print_char ',';
      print_list node; print_char ',';
      print_list sgn
  | (smb, n1, n2, sgn)::rest ->
      print_node_input_acc
	(smb::symbol_acc) (n2::n1::node_acc) ((int_of_sgn sgn)::sgn_acc) rest;;

let print_node_input (lens, data) =
  print_list lens; print_char ',';
  print_node_input_acc [] [] [] data

let rec print_symbol_input_acc node_acc sgn_acc = function
  | [] ->
      let node = List.rev node_acc
      and sgn = List.rev sgn_acc in
      print_list node; print_char ',';
      print_list sgn
  | (n1, n2, n3, sgn)::rest ->
      print_symbol_input_acc (n3::n2::n1::node_acc) ((int_of_sgn sgn)::sgn_acc) rest;;

let print_symbol_input (lens, data) =
  print_list lens; print_char ',';
  print_symbol_input_acc [] [] data

let print_simple_edges (lens, indices) =
  print_list lens;
  print_char ',';
  print_list indices;;

let get_acts_mask acts =
  let mask_ar = Array.make !Logic.total_action 0 in
  acts |> List.iter (fun x ->
    mask_ar.(Logic.hash_to_fl_index x) <- 1;
  );
  Array.to_list mask_ar

let print_for_nn st acts =
  let ( [ node_input1; node_input2; node_input3; symbol_input ],
	[ node_c_input; clause_input ],
	[ ini_nodes; ini_symbols; ini_clauses ] ) = Circuit.state_to_gr_indices st in
  let mask_axiom_only = get_acts_mask acts
  and _, literal_list = clause_input in
  let mask_offset = (List.length literal_list) - (List.length mask_axiom_only) in
  let axiom_mask = List.rev_append (ListE.make mask_offset 0) (mask_axiom_only)
  in
  print_node_input node_input1;    print_char ';';
  print_node_input node_input2;    print_char ';';
  print_node_input node_input3;    print_char ';';
  print_symbol_input symbol_input; print_char ';';
  print_simple_edges node_c_input; print_char ';';
  print_simple_edges clause_input; print_char ';';
  print_list ini_nodes;            print_char ';';
  print_list ini_symbols;          print_char ';';
  print_list ini_clauses;          print_char ';';
  print_list axiom_mask;           print_char '\n';
  Format.print_flush ();;
