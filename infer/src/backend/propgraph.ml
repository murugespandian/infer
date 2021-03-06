(*
 * Copyright (c) 2009 - 2013 Monoidics ltd.
 * Copyright (c) 2013 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

(** Propositions seen as graphs *)

module F = Format
module L = Logging

type t = Prop.normal Prop.t

type node = Sil.exp

type sub_entry = Ident.t * Sil.exp

type edge = Ehpred of Sil.hpred | Eatom of Sil.atom | Esub_entry of sub_entry

let from_prop p = p

(** Return [true] if root node *)
let rec is_root = function
  | Sil.Var id -> Ident.is_normal id
  | Sil.Const _ | Sil.Lvar _ -> true
  | Sil.Cast (_, e) -> is_root e
  | Sil.UnOp _ | Sil.BinOp _ | Sil.Lfield _ | Sil.Lindex _ | Sil.Sizeof _ -> false

(** Return [true] if the nodes are connected. Used to compute reachability. *)
let nodes_connected n1 n2 =
  Sil.exp_equal n1 n2 (* Implemented as equality for now, later it might contain offset by a constant *)

(** Return [true] if the edge is an hpred, and [false] if it is an atom *)
let edge_is_hpred = function
  | Ehpred _ -> true
  | Eatom _ -> false
  | Esub_entry _ -> false

(** Return the source of the edge *)
let edge_get_source = function
  | Ehpred (Sil.Hpointsto(e, _, _)) -> e
  | Ehpred (Sil.Hlseg(_, _, e, _, _)) -> e
  | Ehpred (Sil.Hdllseg(_, _, e1, _, _, _, _)) -> e1 (* only one direction supported for now *)
  | Eatom (Sil.Aeq (e1, _)) -> e1
  | Eatom (Sil.Aneq (e1, _)) -> e1
  | Esub_entry (x, _) -> Sil.Var x

(** Return the successor nodes of the edge *)
let edge_get_succs = function
  | Ehpred hpred -> Sil.ExpSet.elements (Prop.hpred_get_targets hpred)
  | Eatom (Sil.Aeq (_, e2)) -> [e2]
  | Eatom (Sil.Aneq (_, e2)) -> [e2]
  | Esub_entry (_, e) -> [e]

let get_sigma footprint_part g =
  if footprint_part then Prop.get_sigma_footprint g else Prop.get_sigma g
let get_pi footprint_part g =
  if footprint_part then Prop.get_pi_footprint g else Prop.get_pi g
let get_subl footprint_part g =
  if footprint_part then [] else Sil.sub_to_list (Prop.get_sub g)

(** [edge_from_source g n footprint_part is_hpred] finds and edge with the given source [n] in prop [g].
    [footprint_part] indicates whether to search the edge in the footprint part, and [is_pred] whether it is an hpred edge. *)
let edge_from_source g n footprint_part is_hpred =
  let edges =
    if is_hpred
    then IList.map (fun hpred -> Ehpred hpred ) (get_sigma footprint_part g)
    else IList.map (fun a -> Eatom a) (get_pi footprint_part g) @ IList.map (fun entry -> Esub_entry entry) (get_subl footprint_part g) in
  match IList.filter (fun hpred -> Sil.exp_equal n (edge_get_source hpred)) edges with
  | [] -> None
  | edge:: _ -> Some edge

(** [get_succs g n footprint_part is_hpred] returns the successor nodes of [n] in [g].
    [footprint_part] indicates whether to search the successors in the footprint part, and [is_pred] whether to follow hpred edges. *)
let get_succs g n footprint_part is_hpred =
  match edge_from_source g n footprint_part is_hpred with
  | None -> []
  | Some e -> edge_get_succs e

(** [get_edges footprint_part g] returns the list of edges in [g], in the footprint part if [fotprint_part] is true *)
let get_edges footprint_part g =
  let hpreds = get_sigma footprint_part g in
  let atoms = get_pi footprint_part g in
  let subst_entries = get_subl footprint_part g in
  IList.map (fun hpred -> Ehpred hpred) hpreds @ IList.map (fun a -> Eatom a) atoms @ IList.map (fun entry -> Esub_entry entry) subst_entries

let edge_equal e1 e2 = match e1, e2 with
  | Ehpred hp1, Ehpred hp2 -> Sil.hpred_equal hp1 hp2
  | Eatom a1, Eatom a2 -> Sil.atom_equal a1 a2
  | Esub_entry (x1, e1), Esub_entry (x2, e2) -> Ident.equal x1 x2 && Sil.exp_equal e1 e2
  | _ -> false

(** [contains_edge footprint_part g e] returns true if the graph [g] contains edge [e],
    searching the footprint part if [footprint_part] is true. *)
let contains_edge (footprint_part: bool) (g: t) (e: edge) =
  try ignore (IList.find (fun e' -> edge_equal e e') (get_edges footprint_part g)); true
  with Not_found -> false

(** [iter_edges footprint_part f g] iterates function [f] on the edges in [g] in the same order as returned by [get_edges];
    if [footprint_part] is true the edges are taken from the footprint part. *)
let iter_edges footprint_part f g =
  IList.iter f (get_edges footprint_part g)  (* For now simple iterator; later might use a specific traversal *)

(** Graph annotated with the differences w.r.t. a previous graph *)
type diff =
  { diff_newgraph : t; (** the new graph *)
    diff_changed_norm : Obj.t list; (** objects changed in the normal part *)
    diff_cmap_norm : colormap; (** colormap for the normal part *)
    diff_changed_foot : Obj.t list; (** objects changed in the footprint part *)
    diff_cmap_foot : colormap (** colormap for the footprint part *) }

(** Compute the subobjects in [e2] which are different from those in [e1] *)
let compute_exp_diff (e1: Sil.exp) (e2: Sil.exp) : Obj.t list =
  if Sil.exp_equal e1 e2 then [] else [Obj.repr e2]


(** Compute the subobjects in [se2] which are different from those in [se1] *)
let rec compute_sexp_diff (se1: Sil.strexp) (se2: Sil.strexp) : Obj.t list = match se1, se2 with
  | Sil.Eexp (e1, _), Sil.Eexp (e2, _) -> if Sil.exp_equal e1 e2 then [] else [Obj.repr se2]
  | Sil.Estruct (fsel1, _), Sil.Estruct (fsel2, _) ->
      compute_fsel_diff fsel1 fsel2
  | Sil.Earray (e1, esel1, _), Sil.Earray (e2, esel2, _) ->
      compute_exp_diff e1 e2 @ compute_esel_diff esel1 esel2
  | _ -> [Obj.repr se2]

and compute_fsel_diff fsel1 fsel2 : Obj.t list = match fsel1, fsel2 with
  | ((f1, se1):: fsel1'), (((f2, se2) as x):: fsel2') ->
      (match Sil.fld_compare f1 f2 with
       | n when n < 0 -> compute_fsel_diff fsel1' fsel2
       | 0 -> compute_sexp_diff se1 se2 @ compute_fsel_diff fsel1' fsel2'
       | _ -> (Obj.repr x) :: compute_fsel_diff fsel1 fsel2')
  | _, [] -> []
  | [], x:: fsel2' ->
      (Obj.repr x) :: compute_fsel_diff [] fsel2'

and compute_esel_diff esel1 esel2 : Obj.t list = match esel1, esel2 with
  | ((e1, se1):: esel1'), (((e2, se2) as x):: esel2') ->
      (match Sil.exp_compare e1 e2 with
       | n when n < 0 -> compute_esel_diff esel1' esel2
       | 0 -> compute_sexp_diff se1 se2 @ compute_esel_diff esel1' esel2'
       | _ -> (Obj.repr x) :: compute_esel_diff esel1 esel2')
  | _, [] -> []
  | [], x:: esel2' ->
      (Obj.repr x) :: compute_esel_diff [] esel2'

(** Compute the subobjects in [newedge] which are different from those in [oldedge] *)
let compute_edge_diff (oldedge: edge) (newedge: edge) : Obj.t list = match oldedge, newedge with
  | Ehpred (Sil.Hpointsto(_, se1, e1)), Ehpred (Sil.Hpointsto(_, se2, e2)) ->
      compute_sexp_diff se1 se2 @ compute_exp_diff e1 e2
  | Eatom (Sil.Aeq (_, e1)), Eatom (Sil.Aeq (_, e2)) ->
      compute_exp_diff e1 e2
  | Eatom (Sil.Aneq (_, e1)), Eatom (Sil.Aneq (_, e2)) ->
      compute_exp_diff e1 e2
  | Esub_entry (_, e1), Esub_entry (_, e2) ->
      compute_exp_diff e1 e2
  | _ -> [Obj.repr newedge]

(** [compute_diff oldgraph newgraph] returns the list of edges which are only in [newgraph] *)
let compute_diff default_color oldgraph newgraph : diff =
  let compute_changed footprint_part =
    let newedges = get_edges footprint_part newgraph in
    let changed = ref [] in
    let build_changed edge =
      if not (contains_edge footprint_part oldgraph edge) then begin
        match edge_from_source oldgraph (edge_get_source edge) footprint_part (edge_is_hpred edge) with
        | None ->
            let changed_obj = match edge with
              | Ehpred hpred -> Obj.repr hpred
              | Eatom a -> Obj.repr a
              | Esub_entry entry -> Obj.repr entry in
            changed := changed_obj :: !changed
        | Some oldedge -> changed := compute_edge_diff oldedge edge @ !changed
      end in
    IList.iter build_changed newedges;
    let colormap (o: Obj.t) =
      if IList.exists (fun x -> x == o) !changed then Red
      else default_color in
    !changed, colormap in
  let changed_norm, colormap_norm = compute_changed false in
  let changed_foot, colormap_foot = compute_changed true in
  { diff_newgraph = newgraph;
    diff_changed_norm = changed_norm;
    diff_cmap_norm = colormap_norm;
    diff_changed_foot = changed_foot;
    diff_cmap_foot = colormap_foot }

(** [diff_get_colormap footprint_part diff] returns the colormap of a computed diff,
    selecting the footprint colormap if [footprint_part] is true. *)
let diff_get_colormap footprint_part diff =
  if footprint_part then diff.diff_cmap_foot else diff.diff_cmap_norm

(** Print a list of propositions, prepending each one with the given string.
    If !Config.pring_using_diff is true, print the diff w.r.t. the given prop,
    extracting its local stack vars if the boolean is true. *)
let pp_proplist pe0 s (base_prop, extract_stack) f plist =
  let num = IList.length plist in
  let base_stack = fst (Prop.sigma_get_stack_nonstack true (Prop.get_sigma base_prop)) in
  let add_base_stack prop =
    if extract_stack then Prop.replace_sigma (base_stack @ Prop.get_sigma prop) prop
    else Prop.expose prop in
  let update_pe_diff (prop: Prop.normal Prop.t) : printenv =
    if !Config.print_using_diff then
      let diff = compute_diff Blue (from_prop base_prop) (from_prop prop) in
      let cmap_norm = diff_get_colormap false diff in
      let cmap_foot = diff_get_colormap true diff in
      { pe0 with pe_cmap_norm = cmap_norm; pe_cmap_foot = cmap_foot }
    else pe0 in
  let rec pp_seq_newline n f = function
    | [] -> ()
    | [_x] ->
        let pe = update_pe_diff _x in
        let x = add_base_stack _x in
        (match pe.pe_kind with
         | PP_TEXT -> F.fprintf f "%s %d of %d:@\n%a" s n num (Prop.pp_prop pe) x
         | PP_HTML -> F.fprintf f "%s %d of %d:@\n%a@\n" s n num (Prop.pp_prop pe) x
         | PP_LATEX -> F.fprintf f "@[%a@]@\n" (Prop.pp_prop pe) x)
    | _x:: l ->
        let pe = update_pe_diff _x in
        let x = add_base_stack _x in
        (match pe.pe_kind with
         | PP_TEXT -> F.fprintf f "%s %d of %d:@\n%a@\n%a" s n num (Prop.pp_prop pe) x (pp_seq_newline (n + 1)) l
         | PP_HTML -> F.fprintf f "%s %d of %d:@\n%a@\n%a" s n num (Prop.pp_prop pe) x (pp_seq_newline (n + 1)) l
         | PP_LATEX -> F.fprintf f "@[%a@]\\\\@\n\\bigvee\\\\@\n%a" (Prop.pp_prop pe) x (pp_seq_newline (n + 1)) l)
  in pp_seq_newline 1 f plist

(** dump a propset *)
let d_proplist (p: 'a Prop.t) (pl: 'b Prop.t list) =
  L.add_print_action (L.PTproplist, Obj.repr (p, pl))
