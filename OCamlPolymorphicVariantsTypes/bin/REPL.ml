(** Copyright 2024-2027, Ilia Suponev *)

(** SPDX-License-Identifier: LGPL-3.0-or-later *)

open Miniml.Ast
open Miniml.Parser
open Miniml.Parser_utility
open Miniml.Pprinter
open Stdio
open Format

type options =
  { mutable dumpast : bool
  ; mutable file : string option
  }
[@@deriving show { with_path = false }]

let parse_args =
  let opts = { dumpast = false; file = None } in
  let open Arg in
  parse
    [ ( "-dparsetree"
      , Unit (fun _ -> opts.dumpast <- true)
      , "Dump AST of input code of moniML" )
    ; ( "-i"
      , String (fun filename -> opts.file <- Some filename)
      , "Input file of miniML's code to interpret it" )
    ]
    (fun opt ->
      eprintf "Argument '%s' are not supported\n" opt;
      exit ~-1)
    "REPL of miniML";
  opts
;;

let () =
  let opts = parse_args in
  let input =
    match opts.file with
    | Some filename -> In_channel.read_all filename |> String.trim
    | None -> In_channel.input_all stdin |> String.trim
  in
  let parse_result = parse program_parser input in
  if opts.dumpast
  then printf "%s\n" (string_of_parse_result show_program parse_result)
  else pp_parse_result std_formatter pp_program parse_result
;;
