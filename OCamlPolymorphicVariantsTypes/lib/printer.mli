(** Copyright 2024-2027, Ilia Suponev *)

(** SPDX-License-Identifier: LGPL-3.0-or-later *)

open Ast
open Parser_utility

val string_of_literal_parse_result : literal parse_result -> string
val string_of_expression_parse_result : expression parse_result -> string
val string_of_struct_item_parse_result : struct_item parse_result -> string
