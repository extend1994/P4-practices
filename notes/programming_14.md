# P4_14 Programming

## Table of Content
* [Header](#header)
* [Parser](#parser)
* [Table](#table)
* [Action](#action)
* [Control](#control)

## Header

### Header Instance （*Parsed Representation 的一部份*）

* Header **Instance** 類型共兩種，主要差別是 valid bit
  * **Packet Header**
  * **Metadata** 用來存數據和配置信息
    * 兩種類型
      * User-Defined Metadata
      * Standard Intrinsic Metadata
        * 內容為 switch 本身的配置資料（如 port number），不同的 switch 會有不同的資料
        * 如 BMv2 中的 [Simple Switch](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md#intrinsic-metadata)
* parser 透過 extract packet header 產生 header instance
* 在 *Ingress Pipeline* 中、match+action 時，以類似 object 的方式存取（`<instance>.<field>`），進行 add/copy 等操作

### Header Validity

  * Packet header 是否為 valid，要測試後才知道
  * 若 Parent header 為 valid，child header 必為 valid
  * Metadata *永遠* valid

### Standard Intrinsic Metadata

除了各種 switch 都有的 standard metadata 之外，  
不同的 switch 架構會有自己的 intrinsic metadata， ([ref](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md#intrinsic-metadata))

P4 預設定義的 metadata instance `standard_metadata`，欄位包含

* *ingress_port* (read only)  
   封包進入 switch 的 port
* *packet_length* (read only)  
   以 byte 為單位的封包長度，不包含 ethernet header CRC。  
   若 switch 開啟 cut-length 模式，此屬性就不能用來 match 或在 action 中存取。
* ***egress_spec***  
   **specification of an egrss**
   - 在 Ingress Pipeline 中的 match+action 被設定
   - 可以是實體 port，邏輯介面（如 tunnel, LAG, route or a VLAN flood group），或是 multicast 群組
* *egress_port* (read only)  
   封包要出去的實體 port
   * 值由 *Buffering machnism* 決定
   * 只在 egress match+action stage 有效
   * 若 *egress_spec* 指向實體 port 就會相同
   * 若是虛擬 port 則會轉換後寫在這邊
* *egress_instance* (read only)
   * 值由 *Buffering machnism* 決定
   * 只在 egress match+action stage 有效
   * 使用 egress_instance 的目的通常是：當封包被複製（flood、multicast），可以使用 ID 辨別每個封包
* *instance_type*
  * *normal*：一般的
  * *ingress clone*：透過 `clone_i2i` 或 `clone_i2e` 的方式產生的封包
  * *egress clone*：透過 `clone_e2i` 或 `clone_e2e` 的方式產生的封包
  * *recirculated*：透過 `resubmit` 跟 `recirculate` 重送的封包
* *parser_status*
   * 0 表示 parser 沒有問題
   * 非 0 表示有誤
* *parser_error_location*：詳細的 parser 錯誤位置。


- fixed length / variable length
  - 不定長字段計算方法：P4 通過對值為 "\*" 的字段的使用，來支持從 packet 中 parse 出不定長的 header instance。該值為"\*"的字段的寬度，可以通過由長度屬性說明的，按字節計數的首部總長推出。**字段寬度= (8 \*總長-其它定長字段寬度的總和) (單位：==bit==)**

### 存取 header 及其 fields

- Header stack
  - 以 array index 存取
  - 可以 `last` 來存取 stack 最上方、array 最新的 header instance
- 非 header stack
  - 使用 header instance 存取 headerㄋ
- 使用 object 的方式存取 field `headerInstace.field`



### Example

```p4
// normal header
header_type headerTypeName {
  fields {
    fieldName: bitWidth;
  }
  length: lengthExp;
  max_length: constValue;
}

// metadata
header_type metaDataName{
  fields{
    fieldName: bitWidth;
  }
}

// Declare header instance
header headerName headerInstance
// Declare metadata instance
metadata headerName headerInstance
```
- `length`：可以是常數、field name、可變長度(*)、對常數或 field 的加/減/乘/左位移/右位移
- 若 `max_length` 有被使用，run time 時若超過此上限，會發生 parser exception
- `max_length` 不該在被宣告固定長度的 header 裡使用，否則會有 compiler warning

## Parser

```p4
// parse process entrance
parser start{
  [return] _parserName_ // enter this parser
}

parser parserName{
  extract_or_set_statement* //can be nothing
  return_value_type | return select(selectCondition){ ... }
}
```

  * `extract`

    取出特定 packet header

  * `return`
    決定使用哪個 parser method 或是進到 *Ingress Pipeline*

  * `select`

    同 c 語言的 switch-case，依據特定的 field 數值去決定要哪一個 parser 或是 control function

    * selectCondition

      * fieldRef

        e.g. etherType

      * **latest**.fieldName

        latest 表示最近一次使用 extract 的 object，所以如果使用 latest 之前沒有用到 extract 就會有 error

      * current(dataOffeset,dataWidthInBit)

        以目前的 packet offset 位置開始某固定長度所取得的數值。


- Others

  - Parser Exceptions p21,22 (`return parse_error parseErrorName`)

  - Value sets

    ```p4
    parser_value_set value_set_name；
    ```

    * 有屬於自己的 global name space
    * 被定義才能被 parser 使用

## Table

```p4
table tableName {
	reads {
		field1: matchType1;
		field2: matchType2;
		...
	}

	actions {
		action1;
		action2;
		...
	}
	min_size: sizeValue;
  max_size: sizeValue;
  size: sizeValue;
  support_timeout: true or false
}
```

  * `reads`:  **match packet header fields**
    * 宣告哪些 defined header fields 要被 match？
    * 怎麼被 match？
      * *exact* : field value 必須跟 table entry value 一模一樣
      * *ternary* : 用給定的 mask match
      * *lpm* : ( longest prefix match ) termary match 的特例，通常用在 IP match，如 140.113.0.0/16
      * *range* : 只要 value 落在區間就可以
      * *valid* : header_field 有被成功 parse ，就算是 valid
* `actions`  
  match 成功後**可能要做的**的 action，可以有多個，確切要做什麼是看 rule 怎麼下
* size

    * `min_size`: table 最少要有幾個 entries 符合，否則會有 error 出現
    * `max_size`: entries 最大數量，超過這個數量，table 不再執行 action （ table 可以 support 的最大 entries 數量）
    * `size`: 符合特定 size 才會運作 -> 可以理解成 table entry 的個數
    * 若沒有特別指定， compiler 會設為 default 值
* `support_timeout`  
  是否自動 timeout

## Action

```p4
  //definition
  action actionName([paras]){
    //statements
  }
```
Statements 執行方式是 blocking（非平行執行）

### Primitive Actions

- [Source file](https://github.com/p4lang/behavioral-model/blob/master/targets/simple_switch/primitives.cpp)
- [JSON file](https://github.com/p4lang/p4-hlir/blob/master/p4_hlir/frontend/primitives.json)

- ***set_field***

  為特定 header field 設值

- ***copy_field(dst, src)***

  顧名思義

- ***add_header(headerInstance)***

  加入一個 Header，如果該 Header 已經存在，則不變。Header 預設值為零

- ***remove_header(headerInstance)***

  移除 packet 中的指定 header（ 將 Header 標記為 invalid，也就是說他不會被封裝和 match 到）

- ***modify_field(dst, value[, mask])***

  更改某一個特定值，其中 dst 可以是 `<instance>.<field>` 或 register

- ***add_to_field(dst, value)***

  將 value 加到 dst 中，其中 dst 可以是 `<instance>.<field>` 或 register

- ***add(dst, val1, val2)***

  講兩個數字相加後儲存

- ***modify_field_with_hash_based_offset (dest, field_list_calc, base, size)***

  透過給定一個已經定好的 field list calc，去計算出 hash，並儲存到 dest 中。然後 hash 產生完之後，會在透過下面公式轉換：new_hash = base + hash_val % size

- ***truncate(len)***

  將 Packet 在 **egress 階段**截短，其中 len 的單位為 byte。若 packet 長度比 len 短，則不會有影響。

- ***drop()***

  在 *Egress Pipeline* 時把 packet 丟掉（不繼續轉發）

- ***no_op()***

  明確向 switch 表示「不做任何動作」，用於「佔位」

- ***push(array[, count])***

  將新的 Header push 到 Packet 中，舊的 Header 會保留在底層。array 是先定義好的 header array，count 預設為 1

- ***pop(array[, count])***

  將 Packet header pop 到 array 中

- ***generate_digest(receiver, field_list)***

  將特定欄位的資料傳送給 reciver，reciver 是一個數字，代表接收端，而接收端的定義不在 P4 的標準當中。

- 用於 *Ingress Pipeline*

  - ***resubmit([field_list])***

    將 Packet 重新送到 Parser 階段中

  - ***clone_ingress_pkt_to_ingress(clone_spec, [ field_list ] )***

    將目前的封包複製一份傳送回Parser，可縮寫成：clone_i2i

  - ***clone_ingress_pkt_to_egress***

    將目前的封包複製一份傳送到 Buffer 中，可縮寫成：clone_i2e

- 用於 *Egress Pipeline*

  - ***recirculate([field_list])***

    將 Packet 重新送到 Parser 階段中

  - ***clone_egress_pkt_to_ingress***

    將目前的封包複製一份傳送回Parser，可縮寫成：clone_e2i

  - ***clone_egress_pkt_to_egress***

    將目前的封包複製一份傳送到 Buffer 中，可縮寫成：clone_e2e

- ***increment***

  增加/減少 field 的值

- ***checksum***

  算多個 fields 的 checksum

### Action Profile

```p4
  action_profile profile_name {
    actions {
      action 1;
      action 2;
      ...
    }
    [size: const_value;]
    //dynamic_action_selection
    [dynamic_action_selection: selector_name;]
  }

  action_selector selector_name {
    selection_key : field_list_calculation_name ;
  }
```
## Control

```p4
control controlFunctionName {
	apply_table_call | apply_and_select_block | if_else_statement | control_fn_name ( )
}

apply_and_select_block ::= apply ( table_name ) { [ case_list ] }
case_list ::= action_case + | hit_miss_case +
action_case ::= action_or_default control_block
action_or_default ::= action_name | default
hit_miss_case ::= hit_or_miss control_block
hit_or_miss ::= hit | miss
// for more, refer spec p59
```

  * `apply(tableName)` 將 packet 扔到 table 測試

  * ```p4
    apply (tableName) {
      action_case{
    		action_or_default
    	}
    }
    ```

    依據該 table 選到的 action 去決定要執行哪一段 control block


## Others

### Counter

```p4
counter counter_name {
    type : packets | bytes;
    [direct : table_name;| static : table_name;]
    [instance_count : const_value;]
    [min_width : const_value;]
    [staturating;]
}

// 更新計數器
// `index` 為 counter array 的 index，只適用在 static counter
action action_name(whom_to_set, counter_stat_index) {
  count(counter_ref, index);
}
```

- `type`

  使用 `packet`, `byte` 或 `packets_and_bytes` 為 counter 的計數單位

- `direct`

  指定 table 中***所有的 entry*** 都會有一個此類型的 counter，  
  當 counter 對應的 entry 被 match，counter 會**自動**更新，不需要使用 `count`  
  若使用了，compiler 會報錯

- `static`

  使用 `count` action 來增加指定 table 的 counter 值，  
  若被其他的 table 呼叫，compiler 會報錯

- `instance_count`

  宣告 counter 的數量，可被任意 table 使用 `count` 搭配 counter 的 arrayname 或 index 來存取 counter。
  ***注意：*** `direct` 或 `instance_count` 需要且只能選一個來用，否則 compiler 會報錯

- `min_width`

  至少需要多少空間來存此 counter ，單位為 bit

- `staturating`

  使 counter 抵達上限時停止計數，若沒有指定則會歸零

#### Example

```p4
counter packets_by_source_ip {
	type: packets;
	direct: ip_host_table;
}
```

### Meter

```p4
meter meter_name {
    type : bytes | packets;
    result : field_ref;
    [direct_or_static : table_name;]
    [instance_count : const_value;]
}

action action_name(meter_index) {
  execute_meter(meter_ref, index, field);
}
```

- 除了以下屬性，其他屬性與 counter 中的意義相同

- `static`

  使用 `execute_meter` action 來增加指定 table 的 meter 值，  
  若被其他的 table 呼叫，compiler 會報錯

- `result`：使用 `direct` 時，需要指定要存 *meter result* 的欄位

### Register

```p4
register register_name {
  width : const_value;
  [direct_or_static: table_name;]
  [instance_count : const_value;]
  [attributes : signed, saturating;]
}

// use
register_name[const_value]
register_name[const_value].field_name

// actions
register_read(register_array, register_index, destination_field);
register_write(register_array, register_index, value);
```

- 屬性與 counter 中的意義相同
- 存取 register 的 action 為 `register_read` 和 `register_write`

### Field Lists

```p4
field_list field_list_name {
  //possible fields
  field_ref;
  header_ref;
  field_value;
  field_list_name;
  payload;
}
```

- `payload` 表示先前提過 field 的所屬 header 後的封包內容也被包含在 field list 中  
  是為了支援特殊案例，如跨過整個封包或 TCP checksum 的 Ethernet CRC 計算 

### Checksum and Hash-value generators

對封包的一串 bytes 做運算來產生一個整數，應用如：  
**integrity check** 或產生一個 psudo-random 的值 (on a packet-by-packet or flow-by-flow basis)

```p4
field_list_calculation field_list_cal_name {
  input {
    field_list_name;
  }
  algorithm: xor16 | csum16 | crc16 | crc32 | programmable_crc;
  output_width: const_value;
}
```

- `output_width` 單位為 bit

```p4
calculated_field field_ref {
  update_or_verify field_list_cal_name if (valid(header_ref | field_ref))
                                     //or if (field_ref == field_ref)
}

// example
calculated_field tcp.chksum {
  update tcpv4_calc if (valid(ipv4));
  update tcpv6_calc if (valid(ipv6));
  verify tcpv4_calc if (valid(ipv4));
  verify tcpv6_calc if (valid(ipv6));
}
```



