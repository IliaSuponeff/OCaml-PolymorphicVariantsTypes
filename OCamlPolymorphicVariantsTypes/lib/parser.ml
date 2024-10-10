(** Copyright 2024-2027, Ilia Suponev *)

(** SPDX-License-Identifier: LGPL-3.0-or-later *)

open Ast
open Parser_utility

(** Data record which contains [Miniml.Ast]
    view of [binary_operator]
    and it's view in string *)
type binary_operator_parse_data =
  { oper_view : string
  ; oper_ast : binary_operator
  }

(** Parser of some elements sequence:
    - [start]: first element of sequence
    - [element_parser]: parser of one element in sequence
    - [list_converter]: coverter of elements sequence to one new element
    - [separator]: char sequence which splitted sequence elements *)
let element_sequence : 'a 'b. 'a -> 'a parser -> ('a list -> 'b) -> string -> 'b parser =
  fun start element_parser list_converter sep ->
  let next_element sep =
    skip_ws
    *> ssequence sep
    *> (element_parser
        <|> perror (Printf.sprintf "Not found elements after separator: '%s'" sep))
  in
  skip_ws
  *> (ssequence sep
      >>> many (next_element sep)
      >>= fun l -> preturn (list_converter (List.append [ start ] l)))
;;

(** Parser of integer literals: [0 .. Int64.max_int].

    [!] This parser returns also [ParseSuccess] or [ParseFail] *)
let integer =
  let rec helper counter =
    digit
    >>= (fun v -> helper (v + (counter * 10)))
    <|> (preturn counter >>= fun v -> preturn (IntLiteral v))
  in
  skip_ws *> digit >>= fun d -> helper d
;;

(** Parser of boolean literals: [true], [false].

    [!] This parser returns also [ParseSuccess] or [ParseFail] *)
let boolean =
  skip_ws *> ssequence "true"
  <|> ssequence "false"
  >>= fun cl -> preturn (BoolLiteral (List.length cl = 4))
;;

(** Parser of constants expression: [integer] and [boolean]

    [!] This parser returns also [ParseSuccess] or [ParseFail] *)
let const_expr = skip_ws *> integer <|> boolean >>= fun r -> preturn (Const r)

(** Parser of all expression which defines on [Miniml.Ast] module *)
let rec expr state = boolean_expr state

(** Parser of basic expressions: [<unary>] | [<const>] | [<tuple>] | [<block>] *)
and basic_expr state = (skip_ws *> unary_expr <|> bracket_expr <|> const_expr) state

(** Parser of unary expression *)
and unary_expr state =
  let helper =
    symbol '+' *> basic_expr
    <|> (symbol '-' *> skip_ws *> basic_expr >>= fun e -> preturn (Unary (Negate, e)))
  in
  (skip_ws *> (helper <|> symbol '~' *> helper)) state

(** Parser of expression sequence:
    - [start]: first element of sequence
    - [converter]: coverter of elements sequence to one new element
    - [separator]: char sequence which splitted sequence elements *)
and expression_sequence start converter separator =
  element_sequence start expr converter separator

(** Parser of brackets expression:
    - unit: [()]
    - one expression: [(<expr>)]
    - expression block: [(<expr>; ...; <expr>)]
    - tuple: [(<expr>, ..., <expr>)] *)
and bracket_expr state =
  let expr_block ex =
    skip_ws *> expression_sequence ex (fun l -> ExpressionBlock l) ";"
  in
  let tuple_expr ex = skip_ws *> expression_sequence ex (fun l -> Tuple l) "," in
  let brackets_subexpr =
    skip_ws *> expr
    >>= (fun ex ->
          expr_block ex
          <|> tuple_expr ex
          <|> (skip_ws *> symbol ')' >>> preturn ex)
          <|> perror "Unsupported separator of bracket expression")
    <|> preturn (Const UnitLiteral)
  in
  (skip_ws
   *> (symbol '(' *> brackets_subexpr
       <* (skip_ws *> symbol ')' <|> perror "Not found close bracket")))
    state

(** Abstract parser of binary operations
    - [subparser]: parser of subexpression
    - [operations]: list of one priorety level binary operations *)
and binary_expression subparser operations state =
  let operation left oper =
    skip_ws
    *> ssequence oper.oper_view
    *> (subparser
        >>= (fun right -> preturn (Binary (left, oper.oper_ast, right)))
        <|> perror
              (Printf.sprintf
                 "Not found right operand of '%s' binary operator"
                 oper.oper_view))
  in
  let rec next ex =
    skip_ws *> (one_of (List.map (operation ex) operations) >>= fun e -> next e)
    <|> preturn ex
  in
  (skip_ws *> subparser >>= fun ex -> next ex) state

(** Parser of binary expressions such as [<expr> * <expr>] and [<expr> / <expr>] *)
and multiply_expr state =
  binary_expression
    basic_expr
    [ { oper_view = "*"; oper_ast = Multiply }; { oper_view = "/"; oper_ast = Division } ]
    state

(** Parser of binary expressions such as [<expr> + <expr>] and [<expr> - <expr>] *)
and summary_expr state =
  binary_expression
    multiply_expr
    [ { oper_view = "+"; oper_ast = Add }; { oper_view = "-"; oper_ast = Subtract } ]
    state

(** Parser of binary expressions such as
    - [<expr> = <expr>]
    - [<expr> <> <expr>]
    - [<expr> > <expr>]
    - [<expr> < <expr>]
    - [<expr> >= <expr>]
    - [<expr> <= <expr>] *)
and compare_expr state =
  binary_expression
    summary_expr
    [ { oper_view = "="; oper_ast = Equals }
    ; { oper_view = "<>"; oper_ast = Unequals }
    ; { oper_view = ">="; oper_ast = Gte }
    ; { oper_view = "<="; oper_ast = Lte }
    ; { oper_view = ">"; oper_ast = Gt }
    ; { oper_view = "<"; oper_ast = Lt }
    ]
    state

(** Parser of binary expressions such as [<expr> && <expr>] and [<expr> || <expr>] *)
and boolean_expr state =
  binary_expression
    compare_expr
    [ { oper_view = "&&"; oper_ast = And }; { oper_view = "||"; oper_ast = Or } ]
    state
;;