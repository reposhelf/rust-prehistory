
open Common;;

type slots_table = (Ast.slot_key,node_id) Hashtbl.t
type items_table = (Ast.ident,node_id) Hashtbl.t
type block_slots_table = (node_id,slots_table) Hashtbl.t
type block_items_table = (node_id,items_table) Hashtbl.t
;;


type code = {
  code_fixup: fixup;
  code_quads: Il.quads;
  code_vregs_and_spill: (int * fixup) option;
}
;;

type glue =
    GLUE_proc_to_C
  | GLUE_C_to_proc
  | GLUE_upcall of int
  | GLUE_mark of Ast.ty
  | GLUE_mark_frame of node_id
  | GLUE_sweep of Ast.ty
  | GLUE_shallow_copy of Ast.ty
  | GLUE_deep_copy of Ast.ty
  | GLUE_compare of Ast.ty
  | GLUE_hash of Ast.ty
  | GLUE_write of Ast.ty
  | GLUE_read of Ast.ty
;;

type data =
    DATA_str of string
  | DATA_prog of node_id
  | DATA_typeinfo of Ast.ty
;;

type glue_code = (glue, code) Hashtbl.t;;
type item_code = (node_id, code) Hashtbl.t;;
type file_code = (node_id, item_code) Hashtbl.t;;
type data_frags = (data, (fixup * Asm.frag)) Hashtbl.t;;

(* The node_id in the Constr_pred constr_key is the innermost block_id
   of any of the constr's pred name or cargs; this is the *outermost*
   block_id in which its constr_id can possibly be shared. It serves
   only to uniquely identify the constr.
   
   The node_id in the Constr_init constr_key is just a slot id. 
   Constr_init is the builtin (un-named) constraint that means "slot is
   initialized". Not every slot is.
 *)
type constr_key =
    Constr_pred of (Ast.constr * node_id)
  | Constr_init of node_id

type ctxt =
    { ctxt_sess: Session.sess;
      ctxt_block_slots: block_slots_table;
      ctxt_block_items: block_items_table;
      ctxt_all_slots: (node_id,Ast.slot) Hashtbl.t;
      ctxt_slot_owner: (node_id,node_id) Hashtbl.t;
      (* ctxt_slot_keys is just for error messages. *)
      ctxt_slot_keys: (node_id,Ast.slot_key) Hashtbl.t;
      ctxt_all_items: (node_id,Ast.mod_item') Hashtbl.t;
      ctxt_all_native_items: (node_id,Ast.native_mod_item') Hashtbl.t;
      (* ctxt_item_names is just for error messages. *)
      ctxt_item_names: (node_id,Ast.ident) Hashtbl.t;
      ctxt_all_item_types: (node_id,Ast.ty) Hashtbl.t;
      ctxt_all_stmts: (node_id,Ast.stmt) Hashtbl.t;
      ctxt_item_files: (node_id,filename) Hashtbl.t;
      ctxt_lval_to_referent: (node_id,node_id) Hashtbl.t;

      (* Layout-y stuff. *)
      ctxt_slot_aliased: (node_id,unit) Hashtbl.t;
      ctxt_slot_vregs: (node_id,((int option) ref)) Hashtbl.t;
      ctxt_slot_layouts: (node_id,layout) Hashtbl.t;
      ctxt_block_layouts: (node_id,layout) Hashtbl.t;
      ctxt_header_layouts: (node_id,layout) Hashtbl.t;
      ctxt_prog_layouts: (node_id,layout) Hashtbl.t;
      ctxt_frame_sizes: (node_id,int64) Hashtbl.t;
      ctxt_call_sizes: (node_id,int64) Hashtbl.t;

      (* Mutability and GC stuff. *)
      ctxt_mutable_slot_referent: (node_id,unit) Hashtbl.t;

      (* Typestate-y stuff. *)
      ctxt_constrs: (constr_id,constr_key) Hashtbl.t;
      ctxt_constr_ids: (constr_key,constr_id) Hashtbl.t;
      ctxt_preconditions: (node_id,Bitv.t) Hashtbl.t;
      ctxt_postconditions: (node_id,Bitv.t) Hashtbl.t;
      ctxt_prestates: (node_id,Bitv.t) Hashtbl.t;
      ctxt_poststates: (node_id,Bitv.t) Hashtbl.t;
      ctxt_copy_stmt_is_init: (node_id,unit) Hashtbl.t;

      (* Translation-y stuff. *)
      ctxt_lval_is_in_proc_init: (node_id,unit) Hashtbl.t;
      ctxt_fn_fixups: (node_id,fixup) Hashtbl.t;
      ctxt_prog_fixups: (node_id,fixup) Hashtbl.t;
      ctxt_file_fixups: (node_id,fixup) Hashtbl.t;
      ctxt_spill_fixups: (node_id,fixup) Hashtbl.t;
      ctxt_abi: Abi.abi;
      ctxt_c_to_proc_fixup: fixup;
      ctxt_proc_to_c_fixup: fixup;
      ctxt_file_code: file_code;
      ctxt_glue_code: glue_code;
      ctxt_data: data_frags;
      ctxt_main_prog: fixup;
      ctxt_main_name: string;
    }
;;

let new_ctxt sess abi crate =
  { ctxt_sess = sess;
    ctxt_block_slots = Hashtbl.create 0;
    ctxt_block_items = Hashtbl.create 0;
    ctxt_all_slots = Hashtbl.create 0;
    ctxt_slot_owner = Hashtbl.create 0;
    ctxt_slot_keys = Hashtbl.create 0;
    ctxt_all_items = Hashtbl.create 0;
    ctxt_all_native_items = Hashtbl.create 0;
    ctxt_item_names = Hashtbl.create 0;
    ctxt_all_item_types = Hashtbl.create 0;
    ctxt_all_stmts = Hashtbl.create 0;
    ctxt_item_files = crate.Ast.crate_files;
    ctxt_lval_to_referent = Hashtbl.create 0;

    ctxt_mutable_slot_referent = Hashtbl.create 0;

    ctxt_constrs = Hashtbl.create 0;
    ctxt_constr_ids = Hashtbl.create 0;
    ctxt_preconditions = Hashtbl.create 0;
    ctxt_postconditions = Hashtbl.create 0;
    ctxt_prestates = Hashtbl.create 0;
    ctxt_poststates = Hashtbl.create 0;
    ctxt_copy_stmt_is_init = Hashtbl.create 0;

    ctxt_slot_aliased = Hashtbl.create 0;
    ctxt_slot_vregs = Hashtbl.create 0;
    ctxt_slot_layouts = Hashtbl.create 0;
    ctxt_block_layouts = Hashtbl.create 0;
    ctxt_header_layouts = Hashtbl.create 0;
    ctxt_prog_layouts = Hashtbl.create 0;
    ctxt_frame_sizes = Hashtbl.create 0;
    ctxt_call_sizes = Hashtbl.create 0;

    ctxt_lval_is_in_proc_init = Hashtbl.create 0;
    ctxt_fn_fixups = Hashtbl.create 0;
    ctxt_prog_fixups = Hashtbl.create 0;
    ctxt_file_fixups = Hashtbl.create 0;
    ctxt_spill_fixups = Hashtbl.create 0;
    ctxt_abi = abi;
    ctxt_c_to_proc_fixup = new_fixup "c-to-proc glue";
    ctxt_proc_to_c_fixup = new_fixup "proc-to-c glue";
    ctxt_file_code = Hashtbl.create 0;
    ctxt_glue_code = Hashtbl.create 0;
    ctxt_data = Hashtbl.create 0;
    ctxt_main_prog = new_fixup "main prog fixup";
    ctxt_main_name = Ast.fmt_to_str Ast.fmt_name crate.Ast.crate_main
  }
;;

exception Semant_err of ((node_id option) * string)
;;

let err (idopt:node_id option) =
  let k s =
    raise (Semant_err (idopt, s))
  in
    Printf.ksprintf k
;;

(* Convenience accessors. *)
let lval_to_referent (cx:ctxt) (id:node_id) : node_id =
  if Hashtbl.mem cx.ctxt_lval_to_referent id
  then Hashtbl.find cx.ctxt_lval_to_referent id
  else failwith "Unresolved lval"
;;

let lval_to_slot (cx:ctxt) (id:node_id) : Ast.slot =
  let referent = lval_to_referent cx id in
    if Hashtbl.mem cx.ctxt_all_slots referent
    then Hashtbl.find cx.ctxt_all_slots referent
    else err (Some referent) "Unknown slot"
;;

let get_slot_owner (cx:ctxt) (id:node_id) : node_id =
  match htab_search cx.ctxt_slot_owner id with
      None -> err (Some id) "Slot has no defined owner"
    | Some owner -> owner
;;

let get_prog (cx:ctxt) (id:node_id) : Ast.prog =
  match Hashtbl.find cx.ctxt_all_items id with
      Ast.MOD_ITEM_prog p -> p.Ast.decl_item
    | _ -> err (Some id) "Node did not map to a program"
;;

let get_prog_owning_slot (cx:ctxt) (id:node_id) : Ast.prog =
  get_prog cx (get_slot_owner cx id)
;;

let slot_is_owned_by_prog (cx:ctxt) (id:node_id) : bool =
  match htab_search cx.ctxt_all_items (get_slot_owner cx id) with
      Some (Ast.MOD_ITEM_prog _) -> true
    | _ -> false
;;

let get_block_layout (cx:ctxt) (id:node_id) : layout =
  if Hashtbl.mem cx.ctxt_block_layouts id
  then Hashtbl.find cx.ctxt_block_layouts id
  else err (Some id) "Unknown block layout"
;;

let get_fn_fixup (cx:ctxt) (id:node_id) : fixup =
  if Hashtbl.mem cx.ctxt_fn_fixups id
  then Hashtbl.find cx.ctxt_fn_fixups id
  else err (Some id) "Fn without fixup"
;;

let get_prog_fixup (cx:ctxt) (id:node_id) : fixup =
  if Hashtbl.mem cx.ctxt_prog_fixups id
  then Hashtbl.find cx.ctxt_prog_fixups id
  else err (Some id) "Prog without fixup"
;;

let get_framesz (cx:ctxt) (id:node_id) : int64 =
  if Hashtbl.mem cx.ctxt_frame_sizes id
  then Hashtbl.find cx.ctxt_frame_sizes id
  else err (Some id) "Missing framesz"
;;

let get_callsz (cx:ctxt) (id:node_id) : int64 =
  if Hashtbl.mem cx.ctxt_call_sizes id
  then Hashtbl.find cx.ctxt_call_sizes id
  else err (Some id) "Missing callsz"
;;

let get_spill (cx:ctxt) (id:node_id) : fixup =
  if Hashtbl.mem cx.ctxt_spill_fixups id
  then Hashtbl.find cx.ctxt_spill_fixups id
  else err (Some id) "Missing spill fixup"
;;

let slot_ty (s:Ast.slot) : Ast.ty =
  match s.Ast.slot_ty with
      Some t -> t
    | None -> err None "untyped slot"
;;


(* Constraint manipulation. *)

let rec apply_names_to_carg_path
    (names:(Ast.name_base option) array)
    (cp:Ast.carg_path)
    : Ast.carg_path =
  match cp with
      Ast.CARG_ext (Ast.CARG_base Ast.BASE_formal,
                    Ast.COMP_idx i) ->
        begin
          match names.(i) with
              Some nb ->
                Ast.CARG_base (Ast.BASE_named nb)
            | None -> err None "Indexing off non-named carg"
        end
    | Ast.CARG_ext (cp', e) ->
        Ast.CARG_ext (apply_names_to_carg_path names cp', e)
    | _ -> cp
;;

let apply_names_to_carg
    (names:(Ast.name_base option) array)
    (carg:Ast.carg)
    : Ast.carg =
  match carg with
      Ast.CARG_path cp ->
        Ast.CARG_path (apply_names_to_carg_path names cp)
    | Ast.CARG_lit _ -> carg
;;

let apply_names_to_constr
    (names:(Ast.name_base option) array)
    (constr:Ast.constr)
    : Ast.constr =
  { constr with
      Ast.constr_args =
      Array.map (apply_names_to_carg names) constr.Ast.constr_args }
;;

let atoms_to_names (atoms:Ast.atom array)
    : (Ast.name_base option) array =
  Array.map
    begin
      fun atom ->
        match atom with
            Ast.ATOM_lval (Ast.LVAL_base nbi) -> Some nbi.node
          | _ -> None
    end
    atoms
;;

let rec lval_base_id (lv:Ast.lval) : node_id =
  match lv with
      Ast.LVAL_base nbi -> nbi.id
    | Ast.LVAL_ext (lv, _) -> lval_base_id lv
;;

let rec lval_base_slot (cx:ctxt) (lv:Ast.lval) : node_id option =
  match lv with
      Ast.LVAL_base nbi ->
        let referent = lval_to_referent cx nbi.id in
          if Hashtbl.mem cx.ctxt_all_slots referent
          then Some referent
          else None
    | Ast.LVAL_ext (lv, _) -> lval_base_slot cx lv
;;

let rec lval_slots (cx:ctxt) (lv:Ast.lval) : node_id array =
  match lv with
      Ast.LVAL_base nbi ->
        let referent = lval_to_referent cx nbi.id in
          if Hashtbl.mem cx.ctxt_all_slots referent
          then [| referent |]
          else [| |]
    | Ast.LVAL_ext (lv, Ast.COMP_named _) -> lval_slots cx lv
    | Ast.LVAL_ext (lv, Ast.COMP_atom a) ->
        Array.append (lval_slots cx lv) (atom_slots cx a)

and atom_slots (cx:ctxt) (a:Ast.atom) : node_id array =
  match a with
      Ast.ATOM_literal _ -> [| |]
    | Ast.ATOM_lval lv -> lval_slots cx lv
;;

let lval_option_slots (cx:ctxt) (lv:Ast.lval option) : node_id array =
  match lv with
      None -> [| |]
    | Some lv -> lval_slots cx lv
;;


let atoms_slots (cx:ctxt) (az:Ast.atom array) : node_id array =
  Array.concat (List.map (atom_slots cx) (Array.to_list az))
;;

let modes_and_atoms_slots (cx:ctxt) (az:(Ast.mode * Ast.atom) array) : node_id array =
  Array.concat (List.map (fun (_,a) -> atom_slots cx a) (Array.to_list az))
;;

let entries_slots (cx:ctxt)
    (entries:(Ast.ident * Ast.mode * Ast.atom) array) : node_id array =
  Array.concat (List.map
                  (fun (_, _, atom) -> atom_slots cx atom)
                  (Array.to_list entries))
;;

let expr_slots (cx:ctxt) (e:Ast.expr) : node_id array =
    match e with
        Ast.EXPR_binary (_, a, b) ->
          Array.append (atom_slots cx a) (atom_slots cx b)
      | Ast.EXPR_unary (_, u) -> atom_slots cx u
      | Ast.EXPR_atom a -> atom_slots cx a
;;


(* Type extraction. *)

let interior_slot_full mut ty : Ast.slot =
  { Ast.slot_mode = Ast.MODE_interior mut;
    Ast.slot_ty = Some ty }
;;

let interior_slot ty : Ast.slot = interior_slot_full Ast.IMMUTABLE ty
;;

(* Mutability analysis. *)


let slot_is_mutable (s:Ast.slot) : bool =
  match s.Ast.slot_mode with
      Ast.MODE_exterior Ast.MUTABLE
    | Ast.MODE_interior Ast.MUTABLE -> true
    | _ -> false
;;

let rec type_is_mutable (t:Ast.ty) : bool =
  match t with
      Ast.TY_any
    | Ast.TY_nil
    | Ast.TY_bool
    | Ast.TY_mach _
    | Ast.TY_int
    | Ast.TY_char
    | Ast.TY_str -> false

    | Ast.TY_tup ttup -> ty_tup_is_mutable ttup
    | Ast.TY_vec s -> slot_or_type_is_mutable s
    | Ast.TY_rec trec ->
        Array.fold_left
          (fun b (_, s) ->
             if b then b else slot_or_type_is_mutable s)
          false trec

    | Ast.TY_tag ttag -> ty_tag_is_mutable ttag
    | Ast.TY_idx idx -> false

    | Ast.TY_iso tiso ->
        Array.fold_left
          (fun b t' ->
             if b then b else ty_tag_is_mutable t')
          false tiso.Ast.iso_group

    | Ast.TY_fn (_, taux) ->
        (match taux.Ast.fn_purity with
             Ast.PURE -> false
           | Ast.IMPURE Ast.MUTABLE -> true
           | Ast.IMPURE Ast.IMMUTABLE -> false)

    | Ast.TY_pred _
    | Ast.TY_chan _
    | Ast.TY_prog _
    | Ast.TY_type -> false

    | Ast.TY_port _
    | Ast.TY_proc -> true

    | Ast.TY_constrained (t', _) -> type_is_mutable t'
    | Ast.TY_opaque (_, Ast.MUTABLE) -> true
    | Ast.TY_opaque (_, Ast.IMMUTABLE) -> false

    | Ast.TY_named _ ->
        err None "unresolved named type in type_is_mutable"

    | Ast.TY_mod mtis ->
        err None "unimplemented mod-type in type_is_mutable"

and slot_or_type_is_mutable (s:Ast.slot) : bool =
  if slot_is_mutable s
  then true
  else type_is_mutable (slot_ty s)

and ty_tag_is_mutable (ttag:Ast.ty_tag) : bool =
  htab_fold
    (fun _ t' b ->
       if b then b else ty_tup_is_mutable t')
    false ttag

and ty_tup_is_mutable (ttup:Ast.ty_tup) : bool =
  Array.fold_left
    (fun b s ->
       if b then b else slot_or_type_is_mutable s)
    false ttup
;;


(* GC analysis. *)

(* A type has to be cyclic in order to live in GC memory. *)
(* FIXME: I'm not sure, by this stage, that the exteriors-list can
 * ever actually collide; I think we might have tied everything into
 * iso groups by now. If so, a simpler predicate just checking for 
 * exterior mutable iso or idx types may suffice.
 *)
let rec type_is_cyclic (exteriors:Ast.ty list) (t:Ast.ty) : bool =

  match t with
      Ast.TY_any
    | Ast.TY_nil
    | Ast.TY_bool
    | Ast.TY_mach _
    | Ast.TY_int
    | Ast.TY_char
    | Ast.TY_str -> false

    | Ast.TY_tup ttup -> ty_tup_is_cyclic exteriors ttup
    | Ast.TY_vec s -> slot_is_cyclic (t :: exteriors) s
    | Ast.TY_rec trec ->
        Array.fold_left
          (fun b (_, s) ->
             if b then b else slot_is_cyclic exteriors s)
          false trec

    | Ast.TY_tag ttag -> ty_tag_is_cyclic exteriors ttag
    | Ast.TY_idx idx -> false

    | Ast.TY_iso tiso ->
        Array.fold_left
          (fun b t' ->
             if b then b else ty_tag_is_cyclic exteriors t')
          false tiso.Ast.iso_group

    | Ast.TY_fn (_, taux) ->
        (match taux.Ast.fn_purity with
             Ast.PURE -> false
           | Ast.IMPURE Ast.MUTABLE -> true
           | Ast.IMPURE Ast.IMMUTABLE -> false)

    | Ast.TY_pred _
    | Ast.TY_chan _
    | Ast.TY_prog _
    | Ast.TY_type -> false

    | Ast.TY_port _
    | Ast.TY_proc -> false

    | Ast.TY_constrained (t', _) -> type_is_cyclic exteriors t'
    | Ast.TY_opaque (_, Ast.MUTABLE) -> true
    | Ast.TY_opaque (_, Ast.IMMUTABLE) -> false

    | Ast.TY_named _ ->
        err None "unresolved named type in type_is_cyclic"

    | Ast.TY_mod mtis ->
        err None "unimplemented mod-type in type_is_cyclic"

and slot_is_cyclic (exteriors:Ast.ty list) (s:Ast.slot) : bool =
  let ty = slot_ty s in
  match (s.Ast.slot_mode, ty) with
      (Ast.MODE_exterior Ast.MUTABLE, _) when List.mem ty exteriors -> true
    | (Ast.MODE_exterior Ast.MUTABLE, Ast.TY_iso _) -> true
    | (Ast.MODE_exterior Ast.MUTABLE, Ast.TY_idx _) -> true
    | _ ->
        let exteriors' =
          match s.Ast.slot_mode with
              Ast.MODE_exterior _ -> ty :: exteriors
            | _ -> exteriors
        in
          type_is_cyclic exteriors' ty

and ty_tag_is_cyclic (exteriors:Ast.ty list) (ttag:Ast.ty_tag) : bool =
  htab_fold
    (fun _ t' b ->
       if b then b else ty_tup_is_cyclic exteriors t')
    false ttag

and ty_tup_is_cyclic (exteriors:Ast.ty list) (ttup:Ast.ty_tup) : bool =
  Array.fold_left
    (fun b s ->
       if b then b else slot_is_cyclic exteriors s)
    false ttup
;;


(* NB: this will fail if lval resolves to an item not a slot! *)
let rec lval_slot (cx:ctxt) (lval:Ast.lval) : Ast.slot =
  match lval with
      Ast.LVAL_base nb -> lval_to_slot cx nb.id
    | Ast.LVAL_ext (base, comp) ->
        let base_ty = slot_ty (lval_slot cx base) in
          match (base_ty, comp) with
              (Ast.TY_rec elts, Ast.COMP_named (Ast.COMP_ident id)) ->
                begin
                  match atab_search elts id with
                      Some slot -> slot
                    | None -> err None "unknown record-member '%s'" id
                end

            | (Ast.TY_tup elts, Ast.COMP_named (Ast.COMP_idx i)) ->
                if 0 <= i && i < (Array.length elts)
                then elts.(i)
                else err None "out-of-range tuple index %d" i

            | (Ast.TY_vec slot, Ast.COMP_atom _) ->
                slot

            | (_,_) -> err None "unhandled form of lval-ext"
;;


let lval_is_slot (cx:ctxt) (lval:Ast.lval) : bool =
  let base_id = lval_base_id lval in
  let referent = lval_to_referent cx base_id in
    Hashtbl.mem cx.ctxt_all_slots referent
;;

let lval_ty (cx:ctxt) (lval:Ast.lval) : Ast.ty =
  let base_id = lval_base_id lval in
  let referent = lval_to_referent cx base_id in
  if Hashtbl.mem cx.ctxt_all_slots referent
  then
    match (lval_slot cx lval).Ast.slot_ty with
        Some t -> t
      | None -> err (Some referent) "Referent has un-inferred type"
  else
    match lval with
        Ast.LVAL_base _ ->
          (Hashtbl.find cx.ctxt_all_item_types referent)
      | _ -> err (Some base_id) "Unimplemented structured item-reference"
;;

let rec atom_type (cx:ctxt) (at:Ast.atom) : Ast.ty =
  match at with
      Ast.ATOM_literal {node=(Ast.LIT_int _); id=_} -> Ast.TY_int
    | Ast.ATOM_literal {node=(Ast.LIT_bool _); id=_} -> Ast.TY_bool
    | Ast.ATOM_literal {node=(Ast.LIT_char _); id=_} -> Ast.TY_char
    | Ast.ATOM_literal {node=(Ast.LIT_nil); id=_} -> Ast.TY_nil
    | Ast.ATOM_literal _ -> err None "unhandled form of literal '%a', in atom_type" Ast.sprintf_atom at
    | Ast.ATOM_lval lv -> lval_ty cx lv
;;

let expr_type (cx:ctxt) (e:Ast.expr) : Ast.ty =
  match e with
      Ast.EXPR_binary (op, a, _) ->
        begin
          match op with
              Ast.BINOP_eq | Ast.BINOP_ne | Ast.BINOP_lt  | Ast.BINOP_le
            | Ast.BINOP_ge | Ast.BINOP_gt -> Ast.TY_bool
            | _ -> atom_type cx a
        end
    | Ast.EXPR_unary (Ast.UNOP_not, _) -> Ast.TY_bool
    | Ast.EXPR_unary (_, a) -> atom_type cx a
    | Ast.EXPR_atom a -> atom_type cx a
;;


(* Mappings between mod items and their respective types. *)

let rec ty_mod_of_mod (inside:bool) (m:Ast.mod_items) : Ast.mod_type_items =
  let ty_items = Hashtbl.create (Hashtbl.length m) in
  let add n i =
    match mod_type_item_of_mod_item inside i with
        None -> ()
      | Some mty -> Hashtbl.add ty_items n mty
  in
    Hashtbl.iter add m;
    ty_items

and mod_type_item_of_mod_item
    (inside:bool)
    (item:Ast.mod_item)
    : Ast.mod_type_item option =
  let decl params item =
    { Ast.decl_params = params;
      Ast.decl_item = item }
  in
  let tyo =
    match item.node with
        Ast.MOD_ITEM_opaque_type td ->
          if inside
          then
            Some (Ast.MOD_TYPE_ITEM_public_type td)
          else
            Some (Ast.MOD_TYPE_ITEM_opaque_type (decl td.Ast.decl_params ()))
      | Ast.MOD_ITEM_public_type td ->
          Some (Ast.MOD_TYPE_ITEM_public_type td)
      | Ast.MOD_ITEM_pred pd ->
          Some (Ast.MOD_TYPE_ITEM_pred
                  (decl pd.Ast.decl_params (ty_pred_of_pred pd.Ast.decl_item)))
      | Ast.MOD_ITEM_mod md ->
          Some (Ast.MOD_TYPE_ITEM_mod
                  (decl md.Ast.decl_params (ty_mod_of_mod true md.Ast.decl_item)))
      | Ast.MOD_ITEM_fn fd ->
          Some (Ast.MOD_TYPE_ITEM_fn
                  (decl fd.Ast.decl_params (ty_fn_of_fn fd.Ast.decl_item)))
      | Ast.MOD_ITEM_prog pd ->
          Some (Ast.MOD_TYPE_ITEM_prog
                  (decl pd.Ast.decl_params (ty_prog_of_prog pd.Ast.decl_item)))
      | Ast.MOD_ITEM_tag _ -> None
  in
    match tyo with
        None -> None
      | Some ty ->
          Some { id = item.id;
                 node = ty }


and ty_mod_of_native_mod (m:Ast.native_mod_items) : Ast.mod_type_items =
  let ty_items = Hashtbl.create (Hashtbl.length m) in
  let add n i = Hashtbl.add ty_items n (mod_type_item_of_native_mod_item i)
  in
    Hashtbl.iter add m;
    ty_items

and mod_type_item_of_native_mod_item
    (item:Ast.native_mod_item)
    : Ast.mod_type_item =
  let decl inner = { Ast.decl_params = [| |];
                     Ast.decl_item = inner }
  in
  let mti =
    match item.node with
        Ast.NATIVE_fn fn ->
          Ast.MOD_TYPE_ITEM_fn (decl (ty_fn_of_native_fn fn))
      | Ast.NATIVE_type mty ->
          Ast.MOD_TYPE_ITEM_public_type (decl (Ast.TY_mach mty))
      | Ast.NATIVE_mod m ->
          Ast.MOD_TYPE_ITEM_mod (decl (ty_mod_of_native_mod m))
  in
    { id = item.id;
      node = mti }


and ty_prog_of_prog (prog:Ast.prog) : Ast.ty_sig =
  let (inputs, constrs, output)  =
    match prog.Ast.prog_init with
        None -> ([||], [||], interior_slot Ast.TY_nil)
      | Some init -> (arg_slots init.node.Ast.init_input_slots,
                      init.node.Ast.init_input_constrs,
                      init.node.Ast.init_output_slot.node)
  in
  let extended_output =
    let proc_slot = interior_slot Ast.TY_proc in
      interior_slot (Ast.TY_tup [| proc_slot; output |])
  in
    { Ast.sig_input_slots = inputs;
      Ast.sig_input_constrs = constrs;
      Ast.sig_output_slot = extended_output }

and arg_slots (slots:Ast.header_slots) : Ast.slot array =
  Array.map (fun (sid,_) -> sid.node) slots

and tup_slots (slots:Ast.header_tup) : Ast.slot array =
  Array.map (fun sid -> sid.node) slots

and ty_fn_of_fn (fn:Ast.fn) : Ast.ty_fn =
  ({ Ast.sig_input_slots = arg_slots fn.Ast.fn_input_slots;
     Ast.sig_input_constrs = fn.Ast.fn_input_constrs;
     Ast.sig_output_slot = fn.Ast.fn_output_slot.node },
   fn.Ast.fn_aux )

and ty_fn_of_native_fn (fn:Ast.native_fn) : Ast.ty_fn =
  ({ Ast.sig_input_slots = arg_slots fn.Ast.native_fn_input_slots;
     Ast.sig_input_constrs = fn.Ast.native_fn_input_constrs;
     Ast.sig_output_slot = fn.Ast.native_fn_output_slot.node },
   { Ast.fn_purity = Ast.IMPURE Ast.IMMUTABLE;
     Ast.fn_proto = None })

and ty_pred_of_pred (pred:Ast.pred) : Ast.ty_pred =
  (arg_slots pred.Ast.pred_input_slots,
   pred.Ast.pred_input_constrs)


and ty_of_native_mod_item (item:Ast.native_mod_item) : Ast.ty =
    match item.node with
      | Ast.NATIVE_type _ -> Ast.TY_type
      | Ast.NATIVE_mod items -> Ast.TY_mod (ty_mod_of_native_mod items)
      | Ast.NATIVE_fn nfn -> Ast.TY_fn (ty_fn_of_native_fn nfn)

and ty_of_mod_item (inside:bool) (item:Ast.mod_item) : Ast.ty =
  let check_concrete params ty =
    if Array.length params = 0
    then ty
    else err (Some item.id) "item has parametric type in ty_of_mod_item"
  in
    match item.node with
        Ast.MOD_ITEM_opaque_type td ->
          check_concrete td.Ast.decl_params Ast.TY_type

      | Ast.MOD_ITEM_public_type td ->
          check_concrete td.Ast.decl_params Ast.TY_type

      | Ast.MOD_ITEM_pred pd ->
          check_concrete pd.Ast.decl_params
            (Ast.TY_pred (ty_pred_of_pred pd.Ast.decl_item))

      | Ast.MOD_ITEM_mod md ->
          check_concrete md.Ast.decl_params
            (Ast.TY_mod (ty_mod_of_mod inside md.Ast.decl_item))

      | Ast.MOD_ITEM_fn fd ->
          check_concrete fd.Ast.decl_params
            (Ast.TY_fn (ty_fn_of_fn fd.Ast.decl_item))

      | Ast.MOD_ITEM_prog pd ->
          check_concrete pd.Ast.decl_params
            (Ast.TY_prog (ty_prog_of_prog pd.Ast.decl_item))

      | Ast.MOD_ITEM_tag td ->
          let (htup, ttag, node) = td.Ast.decl_item in
          let taux = { Ast.fn_purity = Ast.PURE;
                       Ast.fn_proto = None }
          in
          let tsig = { Ast.sig_input_slots = tup_slots htup;
                       Ast.sig_input_constrs = [| |];
                       Ast.sig_output_slot = interior_slot (Ast.TY_tag ttag) }
          in
            check_concrete td.Ast.decl_params
              (Ast.TY_fn (tsig, taux))
;;

(* Scopes and the visitor that builds them. *)

type scope =
    SCOPE_block of node_id
  | SCOPE_mod_item of Ast.mod_item
  | SCOPE_mod_type_item of Ast.mod_type_item
  | SCOPE_crate of Ast.crate
;;

let id_of_scope (sco:scope) : node_id =
  match sco with
      SCOPE_block id -> id
    | SCOPE_mod_item i -> i.id
    | SCOPE_mod_type_item ti -> ti.id
    | SCOPE_crate c -> c.id
;;

let scope_stack_managing_visitor
    (scopes:(scope list) ref)
    (inner:Walk.visitor)
    : Walk.visitor =
  let push s =
    scopes := s :: (!scopes)
  in
  let pop _ =
    scopes := List.tl (!scopes)
  in
  let visit_block_pre b =
    push (SCOPE_block b.id);
    inner.Walk.visit_block_pre b
  in
  let visit_block_post b =
    inner.Walk.visit_block_post b;
    pop();
  in
  let visit_mod_item_pre n p i =
    push (SCOPE_mod_item i);
    inner.Walk.visit_mod_item_pre n p i
  in
  let visit_mod_item_post n p i =
    inner.Walk.visit_mod_item_post n p i;
    pop();
  in
  let visit_mod_type_item_pre n p i =
    push (SCOPE_mod_type_item i);
    inner.Walk.visit_mod_type_item_pre n p i
  in
  let visit_mod_type_item_post n p i =
    inner.Walk.visit_mod_type_item_post n p i;
    pop();
  in
  let visit_crate_pre c =
    push (SCOPE_crate c);
    inner.Walk.visit_crate_pre c
  in
  let visit_crate_post c =
    inner.Walk.visit_crate_post c;
    pop()
  in
    { inner with
        Walk.visit_block_pre = visit_block_pre;
        Walk.visit_block_post = visit_block_post;
        Walk.visit_mod_item_pre = visit_mod_item_pre;
        Walk.visit_mod_item_post = visit_mod_item_post;
        Walk.visit_mod_type_item_pre = visit_mod_type_item_pre;
        Walk.visit_mod_type_item_post = visit_mod_type_item_post;
        Walk.visit_crate_pre = visit_crate_pre;
        Walk.visit_crate_post = visit_crate_post; }
;;

(* Generic lookup, used for slots, items, types, etc. *)
(* 
 * FIXME: currently doesn't lookup inside type-item scopes
 * nor return type variables bound by items. 
 *)
let lookup
    (cx:ctxt)
    (scopes:scope list)
    (key:Ast.slot_key)
    : ((scope list * node_id) option) =
  let check_items scope ident items =
    if Hashtbl.mem items ident
    then
      let item = Hashtbl.find items ident in
        Some item.id
    else
      None
  in
  let is_in_block_scope id =
    let b = ref false in
      List.iter
        (fun scope ->
           (match scope with
                SCOPE_block block_id when block_id = id -> b := true
              | _ -> ()))
        scopes;
      !b
  in
  let check_scope scope =
    match scope with
        SCOPE_block block_id ->
          let block_slots = Hashtbl.find cx.ctxt_block_slots block_id in
          let block_items = Hashtbl.find cx.ctxt_block_items block_id in
            if Hashtbl.mem block_slots key
            then
              let id = Hashtbl.find block_slots key in
                Some id
            else
              begin
                match key with
                    Ast.KEY_temp _ -> None
                  | Ast.KEY_ident ident ->
                      if Hashtbl.mem block_items ident
                      then
                        let id = Hashtbl.find block_items ident in
                          Some id
                      else
                        None
              end

      | SCOPE_crate crate ->
          begin
            match key with
                Ast.KEY_temp _ -> None
              | Ast.KEY_ident ident ->
                  match
                    check_items scope ident crate.node.Ast.crate_items
                  with
                      None ->
                        check_items scope ident crate.node.Ast.crate_native_items
                    | x -> x
          end

      | SCOPE_mod_item item ->
          begin
            match key with
                Ast.KEY_temp _ -> None
              | Ast.KEY_ident ident ->
                  begin
                    let match_input_slot islots =
                      arr_search islots
                        (fun _ (sloti,ident') ->
                           if ident = ident'
                           then Some sloti.id
                           else None)
                    in
                    match item.node with
                        Ast.MOD_ITEM_fn f ->
                          match_input_slot f.Ast.decl_item.Ast.fn_input_slots

                      | Ast.MOD_ITEM_pred p ->
                          match_input_slot p.Ast.decl_item.Ast.pred_input_slots

                      | Ast.MOD_ITEM_mod m ->
                          check_items scope ident m.Ast.decl_item

                      | Ast.MOD_ITEM_prog p ->
                          let check_prog_slots _ =
                            let slots = p.Ast.decl_item.Ast.prog_slots in
                              if Hashtbl.mem slots ident
                              then
                                let slot = Hashtbl.find slots ident in
                                  Some slot.id
                              else
                                check_items scope ident
                                  p.Ast.decl_item.Ast.prog_mod
                          in
                          begin
                            match p.Ast.decl_item.Ast.prog_init with
                                Some input when
                                  is_in_block_scope
                                    input.node.Ast.init_body.id ->
                                  begin
                                    match match_input_slot
                                      input.node.Ast.init_input_slots
                                    with
                                        Some res -> Some res
                                      | None -> check_prog_slots ()
                                  end
                              | _ -> check_prog_slots ()
                          end
                      | _ -> None
                  end
          end
      | _ -> None
  in
    list_search_ctxt scopes check_scope
;;


let report_err cx ido str =
  let sess = cx.ctxt_sess in
  let spano = match ido with
      None -> None
    | Some id -> (Session.get_span sess id)
  in
    match spano with
        None ->
          Session.fail sess "Error: %s\n%!" str
      | Some span ->
          Session.fail sess "%s:E:Error: %s\n%!"
            (Session.string_of_span span) str


let run_passes
    (cx:ctxt)
    (passes:Walk.visitor array)
    (log:string->unit)
    (crate:Ast.crate)
    : unit =
  let do_pass i p =
    let logger s = log (Printf.sprintf "pass %d: %s" i s) in
      Walk.walk_crate
        (Walk.mod_item_logging_visitor logger p)
        crate
  in
  let sess = cx.ctxt_sess in
    if sess.Session.sess_failed
    then ()
    else
      try
        Array.iteri do_pass passes
      with
          Semant_err (ido, str) -> report_err cx ido str
;;

(* Rust type -> IL type conversion. *)

let rec referent_type (abi:Abi.abi) (t:Ast.ty) : Il.referent_ty =
  let s t = Il.ScalarTy t in
  let v b = Il.ValTy b in
  let p t = Il.AddrTy t in
  let sv b = s (v b) in
  let sp t = s (p t) in

  let word = sv abi.Abi.abi_word_bits in
  let ptr = sp Il.OpaqueTy in

    match t with
        Ast.TY_any -> Il.StructTy [| word;  ptr |]
      | Ast.TY_nil -> s Il.NilTy
      | Ast.TY_int -> word
          (* FIXME: bool should be 8 bit, not word-sized. *)
      | Ast.TY_bool -> word

      | Ast.TY_mach (TY_u8)
      | Ast.TY_mach (TY_s8) -> sv Il.Bits8

      | Ast.TY_mach (TY_u16)
      | Ast.TY_mach (TY_s16) -> sv Il.Bits16

      | Ast.TY_mach (TY_u32)
      | Ast.TY_mach (TY_s32)
      | Ast.TY_mach (TY_f32)
      | Ast.TY_char -> sv Il.Bits32

      | Ast.TY_mach (TY_u64)
      | Ast.TY_mach (TY_s64)
      | Ast.TY_mach (TY_f64) -> sv Il.Bits64

      | Ast.TY_str -> sp (Il.StructTy [| word; word; word; ptr |])
      | Ast.TY_vec _ -> sp (Il.StructTy [| word; word; word; ptr |])
      | Ast.TY_tup tt ->
          Il.StructTy (Array.map (slot_referent_type abi) tt)
      | Ast.TY_rec tr ->
          Il.StructTy
            (Array.map (fun (ident, slot) ->
                          slot_referent_type abi slot) tr)

      | Ast.TY_tag _
      | Ast.TY_iso _
      | Ast.TY_idx _
      | Ast.TY_fn _
      | Ast.TY_pred _
      | Ast.TY_chan _
      | Ast.TY_port _
      | Ast.TY_mod _
      | Ast.TY_proc
      | Ast.TY_opaque _
      | Ast.TY_type -> ptr

      | Ast.TY_prog _ -> sp (Il.StructTy [| ptr; ptr; ptr |])
      | Ast.TY_named _ -> err None "named type in referent_type"
      | Ast.TY_constrained (t, _) -> referent_type abi t

and slot_referent_type (abi:Abi.abi) (sl:Ast.slot) : Il.referent_ty =
  let s t = Il.ScalarTy t in
  let v b = Il.ValTy b in
  let p t = Il.AddrTy t in
  let sv b = s (v b) in
  let sp t = s (p t) in

  let word = sv abi.Abi.abi_word_bits in

  let rty = referent_type abi (slot_ty sl) in
  match sl.Ast.slot_mode with
      Ast.MODE_exterior _ -> sp (Il.StructTy [| word; rty |])
    | Ast.MODE_interior _ -> rty
    | Ast.MODE_read_alias -> sp rty
    | Ast.MODE_write_alias -> sp rty
;;

(* Layout calculations. *)

let new_layout (off:int64) (sz:int64) (align:int64) : layout =
  { layout_offset = off;
    layout_size = sz;
    layout_align = align }
;;

let align_to (align:int64) (v:int64) : int64 =
  if align = 0L || align = 1L
  then v
  else
    let rem = Int64.rem v align in
      if rem = 0L
      then v
      else
        let padding = Int64.sub align rem in
          Int64.add v padding
;;

let pack (offset:int64) (layouts:layout array) : layout =
  let pack_one (off,align) curr =
    curr.layout_offset <- align_to curr.layout_align off;
    ((Int64.add curr.layout_offset curr.layout_size),
     (i64_max align curr.layout_align))
  in
  let (final,align) = Array.fold_left pack_one (offset,0L) layouts in
  let sz = Int64.sub final offset in
    new_layout offset sz align
;;

let word_layout (abi:Abi.abi) (off:int64) : layout =
  new_layout off abi.Abi.abi_word_sz abi.Abi.abi_word_sz
;;

let rec layout_referent (abi:Abi.abi) (off:int64) (rty:Il.referent_ty) : layout =
  match rty with
      Il.ScalarTy sty ->
        begin
          match sty with
              Il.NilTy -> new_layout off 0L 0L
            | Il.ValTy Il.Bits8 -> new_layout off 1L 1L
            | Il.ValTy Il.Bits16 -> new_layout off 2L 2L
            | Il.ValTy Il.Bits32 -> new_layout off 4L 4L
            | Il.ValTy Il.Bits64 -> new_layout off 8L 8L
            | Il.AddrTy _ -> word_layout abi off
        end
    | Il.StructTy rtys ->
        let layouts = Array.map (layout_referent abi 0L) rtys in
          pack off layouts
    | Il.OpaqueTy -> err None "laying out opaque IL type in layout_referent"
;;


let layout_ty (abi:Abi.abi) (off:int64) (t:Ast.ty) : layout =
  layout_referent abi off (referent_type abi t)
;;

(* FIXME: redirect this to slot_referent_type *)
let layout_slot (abi:Abi.abi) (off:int64) (s:Ast.slot) : layout =
  match s.Ast.slot_mode with
      Ast.MODE_interior _
    | _ ->
        begin
          match s.Ast.slot_ty with
              None -> raise (Semant_err (None, "layout_slot on untyped slot"))
            | Some t -> layout_ty abi off t
        end
          (* FIXME: turning this on makes a bunch of slots go into
           * regs (great!)  except they're not supposed to; the
           * alias-analysis pass is supposed to catch them. It doesn't
           * yet, though. *)
          (* | _ -> word_layout abi off *)
;;

let ty_sz (abi:Abi.abi) (t:Ast.ty) : int64 =
  let slot = interior_slot t in
    (layout_slot abi 0L slot).layout_size
;;

let slot_sz (abi:Abi.abi) (s:Ast.slot) : int64 =
  (layout_slot abi 0L s).layout_size
;;

let layout_rec (abi:Abi.abi) (atab:Ast.ty_rec) : ((Ast.ident * (Ast.slot * layout)) array) =
  let layouts = Array.map (fun (_,slot) -> layout_slot abi 0L slot) atab in
    begin
      ignore (pack 0L layouts);
      assert ((Array.length layouts) = (Array.length atab));
      Array.mapi (fun i layout ->
                    let (ident, slot) = atab.(i) in
                      (ident, (slot, layout))) layouts
    end
;;

let layout_tup (abi:Abi.abi) (tup:Ast.ty_tup) : (layout array) =
  let layouts = Array.map (layout_slot abi 0L) tup in
    ignore (pack 0L layouts);
    layouts
;;

let word_slot (abi:Abi.abi) : Ast.slot =
  interior_slot (Ast.TY_mach abi.Abi.abi_word_ty)
;;

let word_write_alias_slot (abi:Abi.abi) : Ast.slot =
  { Ast.slot_mode = Ast.MODE_write_alias;
    Ast.slot_ty = Some (Ast.TY_mach abi.Abi.abi_word_ty) }
;;

let layout_fn_call_tup (abi:Abi.abi) (tsig:Ast.ty_sig) : (layout array) =
  let slots = tsig.Ast.sig_input_slots in
  let proc_ptr = word_slot abi in
  let out_ptr = word_slot abi in
  let slots' = Array.append [| out_ptr; proc_ptr |] slots in
    layout_tup abi slots'
;;

let layout_init_call_tup (abi:Abi.abi) (tsig:Ast.ty_sig) : (layout array) =
  let slots = tsig.Ast.sig_input_slots in
  let init_proc_ptr = word_slot abi in
  let proc_ptr = word_slot abi in
  let out_ptr = word_slot abi in
  let slots' = Array.append [| out_ptr; proc_ptr; init_proc_ptr |] slots in
    layout_tup abi slots'
;;


(*
 * Local Variables:
 * fill-column: 70;
 * indent-tabs-mode: nil
 * buffer-file-coding-system: utf-8-unix
 * compile-command: "make -C ../.. 2>&1 | sed -e 's/\\/x\\//x:\\//g'";
 * End:
 *)
