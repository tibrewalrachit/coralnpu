// Lean compiler output
// Module: CoralNPU.BitVec
// Imports: public import Init public import Sparkle
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_signExt(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_clz(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_signExt___boxed(lean_object*, lean_object*, lean_object*);
lean_object* l_BitVec_shiftLeft(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_ctz_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* l_BitVec_ofInt(lean_object*, lean_object*);
lean_object* l_List_range(lean_object*);
lean_object* l_BitVec_ofNat(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_cpop(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_cpop_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_mask___boxed(lean_object*, lean_object*);
lean_object* lean_nat_land(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_cpop_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt___redArg___boxed(lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_mask(lean_object*, lean_object*);
lean_object* l_BitVec_toInt(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_ctz___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_clz_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_clz_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_ctz_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_clz___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_ctz(lean_object*, lean_object*);
lean_object* l_BitVec_sub(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_cpop___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_mask(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_3 = lean_unsigned_to_nat(1u);
x_4 = l_BitVec_ofNat(x_2, x_3);
x_5 = l_BitVec_shiftLeft(x_2, x_4, x_1);
x_6 = l_BitVec_sub(x_2, x_5, x_4);
lean_dec(x_4);
lean_dec(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_mask___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_CoralNPU_CoralNPU_BitVec_mask(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_signExt(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; 
x_4 = l_BitVec_toInt(x_1, x_3);
x_5 = l_BitVec_ofInt(x_2, x_4);
lean_dec(x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_signExt___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_CoralNPU_CoralNPU_BitVec_signExt(x_1, x_2, x_3);
lean_dec(x_2);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = l_BitVec_ofNat(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt___redArg___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_CoralNPU_CoralNPU_BitVec_zeroExt___redArg(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_BitVec_ofNat(x_2, x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_zeroExt___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_CoralNPU_CoralNPU_BitVec_zeroExt(x_1, x_2, x_3);
lean_dec(x_3);
lean_dec(x_2);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_clz_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_13; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_7 = lean_unsigned_to_nat(1u);
x_13 = lean_nat_dec_eq(x_3, x_5);
if (x_13 == 0)
{
x_8 = x_13;
goto block_12;
}
else
{
lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; uint8_t x_21; 
x_14 = lean_nat_sub(x_1, x_7);
x_15 = lean_nat_sub(x_14, x_5);
lean_dec(x_14);
x_16 = l_BitVec_ofNat(x_1, x_7);
x_17 = l_BitVec_shiftLeft(x_1, x_16, x_15);
lean_dec(x_15);
lean_dec(x_16);
x_18 = lean_nat_land(x_2, x_17);
lean_dec(x_17);
x_19 = lean_unsigned_to_nat(0u);
x_20 = l_BitVec_ofNat(x_1, x_19);
x_21 = lean_nat_dec_eq(x_18, x_20);
lean_dec(x_20);
lean_dec(x_18);
x_8 = x_21;
goto block_12;
}
block_12:
{
if (x_8 == 0)
{
x_4 = x_6;
goto _start;
}
else
{
lean_object* x_10; 
x_10 = lean_nat_add(x_3, x_7);
lean_dec(x_3);
x_3 = x_10;
x_4 = x_6;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_clz_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_clz_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_clz(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_3 = lean_unsigned_to_nat(0u);
lean_inc(x_1);
x_4 = l_List_range(x_1);
x_5 = lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_clz_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
x_6 = l_BitVec_ofNat(x_1, x_5);
lean_dec(x_5);
lean_dec(x_1);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_clz___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_CoralNPU_CoralNPU_BitVec_clz(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_ctz_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; uint8_t x_13; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_13 = lean_nat_dec_eq(x_3, x_5);
if (x_13 == 0)
{
x_7 = x_13;
goto block_12;
}
else
{
lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; uint8_t x_20; 
x_14 = lean_unsigned_to_nat(1u);
x_15 = l_BitVec_ofNat(x_1, x_14);
x_16 = l_BitVec_shiftLeft(x_1, x_15, x_5);
lean_dec(x_15);
x_17 = lean_nat_land(x_2, x_16);
lean_dec(x_16);
x_18 = lean_unsigned_to_nat(0u);
x_19 = l_BitVec_ofNat(x_1, x_18);
x_20 = lean_nat_dec_eq(x_17, x_19);
lean_dec(x_19);
lean_dec(x_17);
x_7 = x_20;
goto block_12;
}
block_12:
{
if (x_7 == 0)
{
x_4 = x_6;
goto _start;
}
else
{
lean_object* x_9; lean_object* x_10; 
x_9 = lean_unsigned_to_nat(1u);
x_10 = lean_nat_add(x_3, x_9);
lean_dec(x_3);
x_3 = x_10;
x_4 = x_6;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_ctz_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_ctz_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_ctz(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_3 = lean_unsigned_to_nat(0u);
lean_inc(x_1);
x_4 = l_List_range(x_1);
x_5 = lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_ctz_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
x_6 = l_BitVec_ofNat(x_1, x_5);
lean_dec(x_5);
lean_dec(x_1);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_ctz___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_CoralNPU_CoralNPU_BitVec_ctz(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_cpop_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_7 = lean_unsigned_to_nat(1u);
x_8 = l_BitVec_ofNat(x_1, x_7);
x_9 = l_BitVec_shiftLeft(x_1, x_8, x_5);
lean_dec(x_8);
x_10 = lean_nat_land(x_2, x_9);
lean_dec(x_9);
x_11 = lean_unsigned_to_nat(0u);
x_12 = l_BitVec_ofNat(x_1, x_11);
x_13 = lean_nat_dec_eq(x_10, x_12);
lean_dec(x_12);
lean_dec(x_10);
if (x_13 == 0)
{
lean_object* x_14; 
x_14 = lean_nat_add(x_3, x_7);
lean_dec(x_3);
x_3 = x_14;
x_4 = x_6;
goto _start;
}
else
{
x_4 = x_6;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_cpop_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_cpop_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_cpop(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_3 = lean_unsigned_to_nat(0u);
lean_inc(x_1);
x_4 = l_List_range(x_1);
x_5 = lp_CoralNPU_List_foldl___at___00CoralNPU_BitVec_cpop_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
x_6 = l_BitVec_ofNat(x_1, x_5);
lean_dec(x_5);
lean_dec(x_1);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_CoralNPU_CoralNPU_BitVec_cpop___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_CoralNPU_CoralNPU_BitVec_cpop(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_sparkle_Sparkle(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_CoralNPU_CoralNPU_BitVec(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_sparkle_Sparkle(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
