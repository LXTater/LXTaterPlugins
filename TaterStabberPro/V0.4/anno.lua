{ Game   : Anno1800.exe
  Version: 
  Date   : 2025-03-10
  Author : bbfox @ https://opencheattables.com
}

[ENABLE]

aobscanmodule(INJECT_MONEY_AND_WAREHOUSE_SLOT,$process,8B 48 20 48 8B C7 89 0F) // should be unique
alloc(newmem,$1000,INJECT_MONEY_AND_WAREHOUSE_SLOT)

label(code)
label(return)
label(i_money_addr1)
label(i_min_money)
label(i_influence_avail_addr)
label(i_influence_total_addr)
label(is_keep_warehouse_slot)
label(i_min_watermark)
label(i_max_watermark is_keep_min_oil)

// 28 *2c 30 *34 *3c= 0
// 68 = 1
// 18 = #1010017 = coin
// 14 != 1A0

newmem:
  cmp dword ptr [rax+18], #1010566
  je oil_base_check
  mov ecx, [rax+20]
  test ecx, ecx
  je code

  mov dword ptr [is_enemy], 0

{
  push rdx
  push rbx
  xor rdx, rdx
  xor rbx, rbx
  mov dword ptr [is_enemy], 1

  mov ebx, [rax+2c]
  add edx, ebx
  mov ebx, [rax+3c]
  add edx, ebx
  mov ebx, [rax+34]
  add edx, ebx
  test edx, edx
  je its_player
  jmp check_if_player_endp

its_player:
  mov dword ptr [is_enemy], 0

check_if_player_endp:
  pop rbx
  pop rdx


  cmp dword ptr [is_enemy], 1
  je check_enemy
}


  // check type, influence, coin for player
check_base_resource:
  mov ecx, [rax+18]
  cmp ecx, #1010190
  je to_influence

  cmp ecx, #1010017
  je check_coin

  cmp ecx, #1010566 // Oil
  jne normal_check
  cmp dword ptr [is_keep_min_oil], 1
  jne normal_check

oil_base_check:
  push rbx
  mov ebx, [rax+20]
  vcvtsi2ss xmm15, xmm15, ebx
  vmovss xmm14, [vf_500]
  vucomiss xmm15, xmm14
  jae oil_endp
  vcvtss2si ebx, xmm14
  mov [rax+20], ebx

oil_endp:
  pop rbx
  jmp code

normal_check:
  //start check warehouse
  mov ecx, [rax+1C]  // max capacity
  test ecx, ecx
  je code

  mov cx, [rax+12]
  cmp cx, F
  jne check_1a_next
  jmp check_1a

check_12_next:
  mov cx, [rax+12]
  cmp cx, 1
  jne code

check_1a:
  mov cx, [rax+1A]
  cmp cx, F
  jne check_1a_next
  jmp check_item_no

check_1a_next:
  mov cx, [rax+1A]
  cmp cx, 1
  je check_item_no

check_1b:
  mov cx, [rax+1A]
  cmp cx, 2
  jne check_item_no

check_1c:
  mov cx, [rax+1A]
  cmp cx, 3
  jne check_item_no

check_1d:
  mov cx, [rax+1A]
  cmp cx, 4
  jne code

check_item_no:
  mov ecx,[rax+20] // item # must >2
  cmp ecx, 2
  jbe code

  jmp to_warehouse

check_warehouse0:
  mov ecx, [rax+18]
  cmp ecx, #1010190
  ja check_warehouse1
  cmp ecx, #110000
  ja check_warehouse2
  jmp code
check_warehouse2: // DLC
  cmp ecx, #150000
  jb to_warehouse

  cmp ecx, #220000 // new DLC
  jb to_warehouse

  jmp code
check_warehouse1: // original
  cmp ecx, #1020000
  jb to_warehouse
  jmp code
  //end check warehouse

check_oil:
  //mov ecx,[rax+20]
  jmp to_warehouse

check_coin:
  push rbx
  push rdx
  xor rdx, rdx
  xor rbx, rbx
  ////mov rbx, [rax+20]
  //cmp rbx, #50000
  //je save_money_addr
  //cmp rbx, #25000
  //je save_money_addr
  //cmp rbx, FFFF
  //jle go_check_enemy

save_money_addr:
  mov ebx, [rax+2c]
  add edx, ebx
  mov ebx, [rax+3c]
  add edx, ebx
  mov ebx, [rax+34]
  add edx, ebx
  cmp edx, 0
  lea rbx, [rax+20]
  jne go_check_enemy

  mov [i_money_addr1], rbx
  mov ebx, [rax+20]
  mov edx, [i_min_money]
  cmp ebx, edx
  cmovb ebx, edx
  mov [rax+20], ebx
  jmp endp_money

go_check_enemy:
  mov dword ptr [is_enemy], 1

endp_money:
  pop rdx
  pop rbx

  cmp dword ptr [is_enemy], 1
  je check_enemy

  jmp code


to_influence:
  push rbx
  lea rbx, [rax+20]
  mov [i_influence_avail_addr], rbx
  lea rbx, [rax+1C]
  mov [i_influence_total_addr], rbx
  pop rbx
  jmp code

to_warehouse:

  push rbx
  mov ebx, [rax+68]
  cmp ebx, 1
  pop rbx
  je code


  cmp dword ptr [is_keep_warehouse_slot], 1
  jne code

  // check if warehouse data exists
  cmp qword ptr [i_warehouse_base], 0
  je code

  // check if warehouse slot id saved in script "Click warehouse -> set stock size"
  push r14
  push rdi
  xor r14, r14
  mov dword ptr [is_warehouse_id_found], 0

loop1:
  mov rdi, i_warehouse_base
  lea rdi, [rdi+r14d*8]
  cmp qword ptr [rdi], 0
  je check_endp
  cmp qword ptr [rdi], rax
  je check_found
  inc r14d
  cmp r14d, #4500  // max 4608
  jae check_endp
  jmp loop1

check_found:
  mov dword ptr [is_warehouse_id_found], 1

check_endp:
  pop rdi
  pop r14
  //  --------------------------

  cmp dword ptr [is_warehouse_id_found], 1
  jne code

  push rcx
  push rbx

  mov ebx, [rax+20]
  mov ecx, [rax+1C]

wh_check_min:
  cmp ebx, 1
  ja wh_check_min1
  jmp warehouse_endp

wh_check_min1:
  cmp ebx, dword ptr [i_min_watermark]
  ja wh_check_max
  mov ebx, [i_min_watermark]
  mov [rax+20], ebx
  jmp warehouse_endp

wh_check_max:
  cmp ecx, dword ptr [i_max_watermark]
  jb warehouse_endp
  mov ebx, [rax+1C]
  sub ebx, dword ptr [i_max_watermark]
  mov [rax+20], ebx
  jmp warehouse_endp


warehouse_endp:
  pop rbx
  pop rcx

  jmp code

check_enemy:


code:
  mov ecx,[rax+20]
  mov rax,rdi
  jmp return

align 10 cc
  i_money_addr1:
  dq 0
  i_min_money:
  dd #100000
  i_influence_avail_addr:
  dq 0
  i_influence_total_addr:
  dq 0
  is_enemy:
  dd 1
  is_keep_warehouse_slot:
  dd 1
  i_min_watermark:
  dd #55
  i_max_watermark:
  dd #10
  is_warehouse_id_found:
  dd 0
  vf_500:
  dd (float)1211
  is_keep_min_oil:
  dd 1

INJECT_MONEY_AND_WAREHOUSE_SLOT:
  jmp newmem
  nop
return:

registersymbol(i_min_watermark)
registersymbol(i_max_watermark is_keep_min_oil)
registersymbol(is_keep_warehouse_slot)
registersymbol(i_influence_total_addr)
registersymbol(i_influence_avail_addr)
registersymbol(i_min_money)
registersymbol(i_money_addr1)
registersymbol(INJECT_MONEY_AND_WAREHOUSE_SLOT)

[DISABLE]

INJECT_MONEY_AND_WAREHOUSE_SLOT:
  db 8B 48 20 48 8B C7

unregistersymbol(*)
dealloc(newmem)

{
// ORIGINAL CODE - INJECTION POINT: Anno1800.exe+10C0802

Anno1800.exe+10C07E6: 8B 48 1C        - mov ecx,[rax+1C]
Anno1800.exe+10C07E9: 2B D1           - sub edx,ecx
Anno1800.exe+10C07EB: 78 61           - js Anno1800.exe+10C084E
Anno1800.exe+10C07ED: 89 17           - mov [rdi],edx
Anno1800.exe+10C07EF: 48 8B C7        - mov rax,rdi
Anno1800.exe+10C07F2: 48 8B 5C 24 30  - mov rbx,[rsp+30]
Anno1800.exe+10C07F7: 48 8B 74 24 38  - mov rsi,[rsp+38]
Anno1800.exe+10C07FC: 48 83 C4 20     - add rsp,20
Anno1800.exe+10C0800: 5F              - pop rdi
Anno1800.exe+10C0801: C3              - ret
// ---------- INJECTING HERE ----------
Anno1800.exe+10C0802: 8B 48 20        - mov ecx,[rax+20]
// ---------- DONE INJECTING  ----------
Anno1800.exe+10C0805: 48 8B C7        - mov rax,rdi
Anno1800.exe+10C0808: 89 0F           - mov [rdi],ecx
Anno1800.exe+10C080A: 48 8B 5C 24 30  - mov rbx,[rsp+30]
Anno1800.exe+10C080F: 48 8B 74 24 38  - mov rsi,[rsp+38]
Anno1800.exe+10C0814: 48 83 C4 20     - add rsp,20
Anno1800.exe+10C0818: 5F              - pop rdi
Anno1800.exe+10C0819: C3              - ret
Anno1800.exe+10C081A: 48 8B 02        - mov rax,[rdx]
Anno1800.exe+10C081D: 48 8B CA        - mov rcx,rdx
Anno1800.exe+10C0820: FF 50 40        - call qword ptr [rax+40]
}