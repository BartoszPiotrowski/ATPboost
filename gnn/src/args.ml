let debug = ref false;;

let do_ucb = ref false;; (* Use the explore/exploit UCB heuristic for MCTS *)
  let ucb_const = ref 1.;; (* the explore/exploit UCB constant *)
  let ucb_mode = ref 0;;

let predict_policy = ref false;;
  let policy_temp = ref 2.;;

let predict_value = ref false;;
  let value_base = ref 0.5;;
  let value_factor = ref 0.5;;
  let length_factor = ref 1.;;

let product_reward = ref false;;

let max_time = ref 1000000000.;;
let max_mem = ref 100000000;;
let max_moves  = ref 200;;
let play_dep = ref 200;;
let play_count = ref 200;;
let thm_play_count = ref (-1);;
let one_per_play = ref true;;
let save_above = ref (-1);;

let gen_average = ref 1.;;

let use_dtree = ref true;; (* use discrimination tree for prefiltering of branches *)
let pre_unify = ref true;;
let conj = ref true;;     (* conjecture-directed: if false neg clauses have # added *)
let def = ref false;;      (* do definitional CNF. More predicates, less clauses *)
let no_proof_subst = ref false;;   (* Much smaller proofs *)

let do_lem = ref true;;

let tosolve = ref "";;
let log_fname = ref "/dev/null";;
let speclist = [
  ("-debug",      Arg.Set debug, "\t\tPrint trees");
  ("-log",        Arg.Set_string log_fname, "\t\t\tFilename for logs");

  ("-ucb",       Arg.Set do_ucb, "\t\t\tEnable the explore/exploit UCB heuristic");
  ("-ucb-nolog", Arg.Unit (fun _ -> ucb_mode := 1), "\t\tUCB without log");
  ("-ucb-pucb", Arg.Unit (fun _ -> ucb_mode := 2), "\t\tuse PUCB instead of UCB");

  ("-ucb-const", Arg.Set_float ucb_const, "\t\tSet the UCB explore/exploit constant; default 1.");
  ("-prod-reward", Arg.Set product_reward, "\t\tuse product reward");

  ("-policy",    Arg.Set predict_policy, "\t\tEnable learned policy");
  ("-pol-temp",  Arg.Set_float policy_temp, "\t\tSet policy softmax temperature");
  ("-value",   Arg.Set predict_value, "\t\tEnable learned value");
  ("-val-base",   Arg.Set_float value_base, "\t\tvalue_base");
  ("-val-fact",   Arg.Set_float value_factor, "\t\tvalue_factor");
  ("-len-fact",   Arg.Set_float length_factor, "\t\tlength_factor");
  ("-avg",        Arg.Set_float gen_average, "\t\t\tGeneralized average");

  ("-time",       Arg.Set_float max_time, "\t\tSet time limit, in sec");
  ("-mem",        Arg.Set_int max_mem, "\t\t\tSet mem limit, in kB");
  ("-moves", Arg.Set_int max_moves, "\t\tSet game depth limit");
  ("-dep", Arg.Set_int play_dep, "\t\t\tSet playout depth; default 200");
  ("-plays", Arg.Set_int play_count, "\t\tSet playout count; default 200");
  ("-thm-plays", Arg.Set_int thm_play_count, "\t\tFast follow a found theorem");
  ("-one-per-play", Arg.Set one_per_play, "\tOpen one MCTS tree node per playout");
  ("-save-above", Arg.Set_int save_above, "\t\tSave states above this number of visits");


  ("-fea-cross", Arg.Set Features.fea_cross, "\t\tCross features");
  ("-fea-pat-len", Arg.Set_int Features.fea_pat_len, "\t\tChoose length of paths (0 = only symbols)");
  ("-fea-unisk", Arg.Set Features.unifyskolems, "\t\tUnify skolems");
  ("-fea-genrand", Arg.Clear Fof.content_names, "\t\tNo Consistent Names");
  ("-fea-nosubst", Arg.Clear Features.fea_undersubst, "\t\tWhen computing features dont descend in substitution");
  ("-fea-nocount", Arg.Set Features.fea_nocount, "\t\tAll present feature counts are fixed to 1");

  ("-nodtree", Arg.Clear use_dtree, "\t\tDisable discrimination tree");
  ("-preunify", Arg.Set pre_unify, "\t\tPre-unify");
  ("-noconj", Arg.Clear conj, "\t\tDisable conjecture-directed search");
  ("-defcnf", Arg.Set def, "\t\tEnable definitional CNF");
  ("-no-prf-sub", Arg.Set no_proof_subst, "\t\tDisable substituted proofs")
];;

if Sys.argv.(0) <> "./top" then
  Arg.parse speclist (fun s -> tosolve := s) "Usage: ./lcop [options] <file.p>\nAvailable options are:";;

