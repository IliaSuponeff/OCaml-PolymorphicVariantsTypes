(** Copyright 2024-2027, Ilia Suponev *)

(** SPDX-License-Identifier: LGPL-3.0-or-later *)

open Ast
open Parser_utility

val integer : literal parser
val boolean : literal parser
val const_expr : expression parser
val basic_expr : expression parser
val unary_expr : expression parser
val bracket_expr : expression parser
val summary_expr : expression parser
val multiply_expr : expression parser
val compare_expr : expression parser
val boolean_expr : expression parser