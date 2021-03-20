open Format
open List

type tm = Var of int
        | App of tm * tm
        | Lam of tm

(* ◻ is the judgement `Kind`
 * ★ is the judgement `Type`
 * Elements of ty are referred to as "Sets", "Sorts", or "Kinds"
 * Whereas terms of type U are referred to as "Types"            *)
type ty = U (* Type *)   (* Type is a kind, ie. (★ : ◻)         *)
        | El of tm       (* Every type is a kind , ie. (★ ≤ ◻)  *)
        | Pi of ty * ty  (* Pi : (◻,◻)                          *)
(* these are the internal types for the base theory *)
(*      | IPi of tm * tm  *)  (* IPi : (★,★)  *)
(*      | IW of tm * tm   *)  (* IW : (★,★)   *)
(*      | ISig of tm * tm *)  (* ISig : (★,★) *)
(*      | Empty *)            (* Empty : ★    *)
(*      | Unit *)             (* Unit : ★     *)
(*      | Bool *)             (* Bool : ★     *)

type sub = tm list
type con = ty list


(****************************************************)
(* Pretty printing                                  *)
(****************************************************)

let rec pp_tm_ k ppf t =
  match t with
  | Var x -> fprintf ppf "x%d" (k - x)
  | Lam s -> fprintf ppf "@[<1>(λx%d. %a)@]" (k + 1) (pp_tm_ (k + 1)) s
  | App(t,u) -> fprintf ppf "@[<1>(%a %a)@]" (pp_tm_ k) t (pp_tm_ k) u
let pp_tm ppf (t : tm) = (pp_tm_ 0 ppf t)

let rec pp_sub_ k ppf (gamma : sub) =
  match gamma with
  | [] -> fprintf ppf "ε"
  | t::gamma -> fprintf ppf "⟨%a , %a⟩" (pp_sub_ k) gamma (pp_tm_ k) t
let pp_sub ppf gamma = pp_sub_ 0 ppf gamma

let rec pp_ty_ k ppf a =
  match a with
  | U -> fprintf ppf "U"
  | El a -> fprintf ppf "(El %a)" (pp_tm_ k) a
  | Pi(a,fam) -> (fprintf ppf "(Pi[x%d:%a] %a)"
                    (k + 1) (pp_ty_ k) a (pp_ty_ (k + 1)) fam)
let pp_ty ppf (a : ty) = (pp_ty_ 0 ppf a)


let rec pp_con_ l k ppf (ctx : con) =
  match ctx with
  | [] -> fprintf ppf "@[<3>"
  | a :: ctx -> (fprintf ppf "%a@ ▹ x%d:%a"
                   (pp_con_ l (k + 1)) ctx (l - k) (pp_ty_ (l - k - 1)) a)
let pp_con ppf ctx = (pp_con_ (length ctx) 0 ppf ctx); (fprintf ppf "@]")


let pp_ty_con ppf ((ctx,a) : con * ty) =
  (fprintf ppf "@[<3>%a@ ⊢ %a@]"
     pp_con ctx (pp_ty_ (length ctx)) a)

let pp_tm_ty_con ppf ((ctx,a,t) : con * ty * tm) =
  (fprintf ppf "@[<3>%a@ @[<2>⊢ %a@ : %a@]@]"
     pp_con ctx (pp_tm_ (length ctx)) t (pp_ty_ (length ctx)) a)



(****************************************************)
(* Type of weakenings                               *)
(****************************************************)
(* These are the morphisms in a category W,
 * whose objects are contexts, and whose morphisms are generated by
 *  W_id : hom(Γ,Γ)
 *  W1 : hom(Γ, Δ) → hom(Γ×U, Δ)
 *  W2 : hom(U, Δ) → hom(Γ×U, Δ×U)
 * Note that this is for a single base type.    *)

type wk = W_id
        | W1 of wk
        | W2 of wk

let rec pp_wk ppf (w : wk) =
  match w with
  | W_id -> fprintf ppf "W_id"
  | W1 w -> fprintf ppf "(W1 %a)" pp_wk w
  | W2 w -> fprintf ppf "(W2 %a)" pp_wk w


(* Composition in W *)
(*  wk_o : hom(Γ,Δ) → hom(Δ,Ξ) → hom(Γ,Ξ)  *)
let rec wk_o (w1 : wk) (w2 : wk) : wk =
  match (w1, w2) with
  | W_id,  _ -> w2
  | W1 w1, w2 -> W1 (wk_o w1 w2)
  | W2 w1, W_id -> W2 w1
  | W2 w1, W1 w2 -> W1 (wk_o w1 w2)
  | W2 w1, W2 w2 -> W2 (wk_o w1 w2)

(****************************************************)
(* type of normal/neutral terms                     *)
(****************************************************)

type nf = NLam of nf   (* Normal terms of type Pi *)
        | NeuU of ne   (* Normal terms of type U *)
        | NeuEl of ne  (* Normal terms of type El *)
and ne = Var_ of int
       | App_ of ne * nf
       (* | Star_
        * | True_
        * | False_
        * | WRec_
        * | EmptyE_ *)

type nesub = ne list

let id (n : int) : nesub =
  let rec id_ k n =
    (if (n = 0) then []
     else (Var_ k) :: (id_ (k + 1) (n - 1)))
  in (id_ 0 n)


let rec nf_tm (t : nf) =
  match t with
  | NLam t -> Lam (nf_tm t)
  | NeuU t -> ne_tm t
  | NeuEl t -> ne_tm t
and ne_tm (t : ne) =
  match t with
  | Var_ k -> Var k
  | App_(t,u) -> App(ne_tm t, nf_tm u)

let pp_nf ppf (t : nf) = pp_tm ppf (nf_tm t)
let pp_ne ppf (t : ne) = pp_tm ppf (ne_tm t)

(* Compute the pullback t[w] for the presheaves Nf/Ne *)
let rec wk_nf (w : wk) (t : nf) : nf =
  match (w,t) with
  | W_id, _ -> t
  | _,    NLam s -> NLam (wk_nf (W2 w) s)
  | _,    NeuU t -> NeuU (wk_ne w t)
  | _,    NeuEl t -> NeuEl (wk_ne w t)
and wk_ne (w : wk) (t : ne) : ne =
  match (w,t) with
  | W_id, _ -> t
  | _,    App_(t,u) -> App_(wk_ne w t, wk_nf w u)
  | W1 w, Var_ x -> wk_ne w (Var_ (x + 1))
  | W2 w, Var_ x -> (if x = 0 then (Var_ 0) else (wk_ne w (Var_ (x - 1))))


(****************************************************)
(* Values                                           *)
(****************************************************)
(* Term values
 * Γ ⊢ t : U         -->  ⟦t⟧(Δ,α) : Nf(Δ,U)
 * Γ ⊢ t : (El s)    -->  ⟦t⟧(Δ,α) : Nf(Δ, El ⟦s⟧(Δ,α))
 * Γ ⊢ t : (Pi A B)  -->  ⟦t⟧(Δ,α) : ⟦Pi A B⟧(Δ,α)                   *)
type vltm = UD of nf
          | ElD of nf
          | PiD of (wk -> (vltm -> vltm))

(* Type values
 * Γ ⊢ A type        -->  α : ⟦Γ⟧(Δ) ⊢ ⟦A⟧(α) : Set
 * ⟦U⟧(Δ,α) = Nf(Δ,U)
 * ⟦El t⟧(Δ,α) = Nf(Δ,El ⟦t⟧(Δ,α))
 * ⟦Pi A B⟧(Δ,α) = (w : 𝕎) -> (x: ⟦A⟧(Ξ, α[w]) -> ⟦B⟧(Ξ, (a[w],x))  *)
type vlty = VU
          | VEl of vltm
          | VPi of vlty * (wk -> (vltm -> vlty))

(* Substitution values
 * Γ ⊢ γ : Δ         -->  α : ⟦Γ⟧(Ξ) ⊢ ⟦γ⟧(Ξ,α) : ⟦Δ⟧(Ξ)
 * ⟦ε⟧(Ξ,α) : ⟦·⟧(Ξ)
 * ⟦⟨ γ , t⟩⟧(Ξ,α) : ⟦Δ ▹ A⟧(Ξ)                                       *)
type vlsub = vltm list

(* Context values
 * ⟦Γ⟧ : Set
 * ⟦·⟧(Δ) = 𝟙
 * ⟦Γ ▹ A⟧(Δ) = Σ ⟦Γ⟧(Δ) (λ α -> ⟦A⟧(Δ,α))                            *)
type vlcon = (vlsub -> vlty) list


(* Pullback a term value through a type value
 *  w : Δ -> Ξ, α : ⟦Γ⟧(Ξ), x : ⟦A⟧(Ξ, α) ⊢ x[w] : ⟦A⟧(Δ, α[w])       *)
let rec wk_vltm (w : wk) (u : vltm) : vltm =
  match u with
  | UD a ->  UD (wk_nf w a)
  | ElD s -> ElD(wk_nf w s)
  | PiD f -> PiD (fun w' u -> f (wk_o w' w) u)

(* Pullback a substitution value through a context value
 *  w : Δ -> Ξ, α : ⟦Γ⟧(Ξ) ⊢ α[w] : ⟦Γ⟧(Δ)                            *)
let wk_vlsub (w : wk) (env : vlsub) : vlsub =
  List.map (wk_vltm w) env


(****************************************************)
(* Evaluation/Reification/Reflection                *)
(****************************************************)

let appD (u : vltm) (v : vltm) : vltm =
  match u with
  | PiD f -> f W_id v
  | _ -> failwith "Not a lambda!"

(* α : ⟦Γ⟧(Δ) ⊢ ⟦t⟧(Δ,α) : ⟦A⟧(Δ,α) *)
let rec eval_tm (t : tm) (env : vlsub) : vltm =
  match t with
  | Var x    -> List.nth env x
  | Lam s    -> PiD (fun w u -> eval_tm s (u::(wk_vlsub w env)))
  | App(t,u) -> appD (eval_tm t env) (eval_tm u env)

(* α : ⟦Γ⟧(Δ) ⊢ ⟦A⟧(Δ,α) : Set *)
let rec eval_ty (a : ty) (env : vlsub) : vlty =
  match a with
  | U         -> VU
  | El t      -> VEl (eval_tm t env)
  | Pi(a,fam) -> VPi(eval_ty a env, (fun w u -> eval_ty fam (u::(wk_vlsub w env))))

(* α : ⟦Γ⟧(Ξ) ⊢ ⟦γ⟧(Ξ,α) : ⟦Δ⟧(Ξ) *)
let rec eval_sub (gamma : sub) (env : vlsub) : vlsub =
  match gamma with
  | []         -> []
  | t :: gamma -> (let env = (eval_sub gamma env) in
                   (eval_tm t env) :: env)

(* ⟦Γ⟧ : Set *)
let rec eval_con (ctx : con) : vlcon =
  match ctx with
  | []     -> []
  | a::ctx -> (fun env -> eval_ty a env) :: (eval_con ctx)

(* Γ : Con, A : Ty Γ  ⊢  q A ⟦t⟧ : Nf(Γ,A) *)
let rec reify_tm (a : ty) (u : vltm) : nf =
  match (a,u) with
  | U,       UD a  -> a
  | El _,    ElD t -> t
  | Pi(a,b), PiD f -> (let v = (reflect_tm a (Var_ 0)) in
                       NLam (reify_tm b (f (W1 W_id) v)))
  | _ -> failwith "Unexpected call to reify_tm!"

(* Γ : Con  ⊢  q ⟦A⟧ : Ty Γ *)
and reify_ty (a : vlty) : ty =
  match a with
  | VU         -> U
  | VEl t      -> El (nf_tm (reify_tm U t))
  | VPi(av,bv) -> (let a = (reify_ty av) in
                   (let v = (reflect_tm a (Var_ 0)) in
                    Pi(a, (reify_ty (bv (W1 W_id) v)))))

(* Γ Δ : Con  ⊢  q Δ ⟦γ⟧ : Sub(Γ,Δ) *)
and reify_sub (ctx : con) (env : vlsub)  : sub =
  match ctx with
  | []       -> []
  | a :: ctx -> (nf_tm (reify_tm a (hd env))) :: (reify_sub ctx (tl env))

(*  ⊢  q ⟦Γ⟧ : Con *)
and reify_con (ctxv : vlcon) : con =
  match ctxv with
  | []         -> []
  | av :: ctxv -> (let ctx = (reify_con ctxv) in
                   (let env = (reflect_sub ctx (id (length ctxv))) in
                    (reify_ty (av env) :: ctx)))

(* Γ : Con, A : Ty Γ, t : Ne(Γ,A), α : ⟦Γ⟧(Δ)  ⊢  u A t : ⟦A⟧(Δ,α)  *)
and reflect_tm (a : ty) (t : ne) : vltm =
  match a with
  | Pi(a,b) -> PiD(fun w u -> reflect_tm b (App_(wk_ne w t, reify_tm a u)))
  | U       -> UD (NeuU t)
  | El _    -> ElD(NeuEl t)

(* Γ Δ : Con, γ : NeSub(Δ,Γ)  ⊢  u Γ γ : ⟦Γ⟧(Δ)  *)
and reflect_sub (ctx : con) (gamma : nesub) : vlsub =
  match ctx with
  | []       -> []
  | a :: ctx -> (reflect_tm a (hd gamma)) :: (reflect_sub ctx (tl gamma))


let nbe_tm (ctx : con) (a : ty) (t : tm) : nf =
  reify_tm a (eval_tm t (reflect_sub ctx (id (length ctx))))

let nbe_ty (ctx : con) (a : ty) : ty =
  reify_ty (eval_ty a (reflect_sub ctx (id (length ctx))))

let nbe_con (ctx : con) : con =
  reify_con (eval_con ctx)

let nbe_sub (ctx : con) (gamma : sub) : sub =
  reify_sub ctx (eval_sub gamma (reflect_sub ctx (id (length ctx))))

(****************************************************************)
(* Tests                                                        *)
(****************************************************************)


let _I = Lam (Var 0)
let _K = Lam (Lam (Var 1))
(* (A -> (B -> C)) -> (A -> B) -> A -> C *)
let _S = Lam (Lam (Lam (App(App(Var 2, Var 0),App(Var 1, Var 0)))))

let tests
  = [(_I, Pi(U,U));
     (_K, Pi(U,Pi(U,U)));
     (Lam(App(_I,Var 0)), Pi(U,U));
     (App(_K,_I), Pi(U,Pi(U,U)));
     (App(Lam (Lam (Lam (App(Var 2, Var 0)))), _I), Pi(U,Pi(U,U)));

     (_S, Pi(Pi(U,Pi(U,U)),Pi(Pi(U,U),Pi(U,U))));
     (Lam (* A : U *) (Lam (* x : El A *) (Var 1)), Pi(U,Pi(El (Var 0), U)));
     (Lam (* A : U *) (Lam (* x : El A *) (Var 0)), Pi(U,Pi(El (Var 0), El (Var 1))));
     (Lam (* A : U *) (Lam (* B : El A -> U *) (Var 1)), Pi(U,Pi(Pi(El(Var 0),U),U)));
     (Lam(Lam(App(Var 0, Var 1))), Pi(U,Pi(Pi(U,U), U)));

     (Lam (* A : U *) (Lam (* B : El A -> U *) (Lam (* x : A *) (App(Var 1, Var 0)))), Pi(U,Pi(Pi(El(Var 0),U), Pi(El(Var 1), U))));
     (Lam (* A : U *) (Lam (* B : El A -> U *) (Lam (* C : (x : A) -> (B x) -> U *) (Lam (* x : A *) (Lam (* y : B x *) (App(App(Var 2, Var 1),Var 0)))))),
      Pi(U, Pi(Pi(El(Var 0),U), Pi(Pi(El(Var 1),Pi(El(App(Var 1,Var 0)),U)), Pi(El(Var 2), Pi(El(App(Var 2,Var 0)), U))))));
     (Lam (* A : U *) (Lam (* x : El A *) (Var 0)), Pi(U, Pi(El (App(_I,Var 0)), El (Var 1))));
     (Lam (* A : U *) (Lam (* B : El A -> El A -> U *) (Lam (* x : El A *) (App(App(Var 1,Var 0),Var 0)))),
      Pi(U, Pi(Pi(El(Var 0), Pi(El(Var 1),U)), Pi(El(Var 1), U))));
     (Lam (* A : U *) (Lam (* B : El A -> El A -> U *) (Lam (* x : El A *) (Lam (* y : El A *) (App(App(Var 2,Var 1),Var 0))))),
      Pi(U, Pi(Pi(El(Var 0),Pi(El(Var 1),U)), Pi(El(Var 1), Pi(El(Var 2),U)))));

     (Lam (Lam (Lam (App(App(Var 2,Var 0),Var 0)))), Pi(Pi(U,Pi(U,U)),Pi(U,Pi(U,U))));
     (Lam (* N : U *) (Lam (* 0 : El N*) (Lam (* S : El N -> El N *) (App(Var 0,App(Var 0,App(Var 0,Var 1)))))), Pi(U, Pi(El(Var 0), Pi(Pi(El(Var 1),El(Var 2)), El(Var 2)))))
    ]

let tm_ty_ctx
  = [([Pi(El(Var 1),El(Var 2)); El(Var 0); U], El(App(_I,Var 2)), App(Var 0,App(Var 0, App(Var 0, Var 1))));
    ]


let sigs
  = [[U];
     [El(Var 0); U];
     [El(Var 1); El(Var 0); U];
     [El(Var 2); El(Var 1); El(Var 0); U];
     [El(Var 3); El(Var 2); El(Var 1); El(Var 0); U];
     [El(App(Var 2,Var 0)); El(Var 2); Pi(El(Var 1),Pi(El(App(Var 1,Var 0)),U)); Pi(El(Var 0),U); U];
     [El(Var 1); El(App(App(_K,Var 0),_I)); U];
     List.rev
       [U; (* Con *)
        Pi(El(Var 0), U); (* Ty *)
        Pi(El(Var 1),Pi(El(App(Var 1,Var 0)), U)); (* Tm *)
        Pi(El(Var 2), Pi(El(Var 3), U)); (* Sub *)
        El(Var 3); (* · *)
        Pi(El(Var 4),Pi(El(App(Var 4, Var 0)), El(Var 6))); (* ▹ *)
        Pi(El(Var 5),Pi(El(Var 6),Pi(El(App(Var 6,Var 0)),Pi(El(App(App(Var 5,Var 2),Var 1)), El(App(Var 8, Var 3)))))); (* _[_]T *)
        Pi(El(Var 6),Pi(El(Var 7),Pi(El(App(Var 7,Var 0)),Pi(El(App(App(Var 7,Var 1),Var 0)),Pi(El(App(App(Var 7,Var 3),Var 2)), El(App(App(Var 9,Var 4),App(App(App(App(Var 5,Var 4),Var 3),Var 2),Var 0)))))))); (* _[_]t *)
        Pi(El(Var 7),El(App(App(Var 5, Var 0),Var 0))); (* id *)
        Pi(El(Var 8),Pi(El(Var 9),Pi(El(Var 10), Pi(El(App(App(Var 8,Var 2),Var 1)), Pi(El(App(App(Var 9,Var 2),Var 1)), El(App(App(Var 10, Var 4), Var 2))))))); (*_∘_*)
        Pi(El(Var 9),El(App(App(Var 7, Var 0),Var 6))); (* ε *)
       ]
]


let _ =
  for i=0 to (length tests) - 1 do
    (let p = (nth tests i) in
     (printf "(%d)@\n%a@ : %a@\n" i pp_tm (fst p) pp_ty (snd p));
     (printf "%a@ : %a@\n" pp_nf (nbe_tm [] (snd p) (fst p))
        pp_ty (nbe_ty [] (snd p))))
  done

let _ =
  for i=0 to (length sigs) - 1 do
    (let p = (nth sigs i) in
     (printf "(%d)@\n%a@\n" i pp_con p);
     (printf "%a@\n" pp_con (nbe_con p)))
  done

let _ =
  for i=0 to (length tm_ty_ctx) - 1 do
    (let (ctx,a,t) = (nth tm_ty_ctx i) in
      (printf "(%d)@\n%a@\n" i pp_tm_ty_con (ctx,a,t));
      (printf "%a\n" pp_tm_ty_con
         (nbe_con ctx, nbe_ty ctx a, nf_tm (nbe_tm ctx a t))))
  done
