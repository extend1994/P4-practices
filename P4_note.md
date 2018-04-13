
P4 整理
===

## Goals
* reconfigurability
  * 描述 target switch 內部的 pipeline，有很多 table，要 match 哪些 fields、做什麼事情，希望下 program 就可以輕易更改 parser。p4 的 compiler 採用了模組化的設計，各模組都有 configurality，像是 p4c-bm 的輸出為 bmv2 的輸入。
* protocol independence
  * 硬體設備不應該被 protocol 所限制，P4 使得我們有能設定 parser 怎麼處理封包，table match 哪些 field 後要做哪些 action，執行 action 的能力跟傳統的 SDN 差很多。
* target independence
  * P4 不希望限制特定的執行平台，希望各式各樣的 switch，甚至網卡和 software switch 都能運行。

## 關於 switch 的結構

### 以往的 SDN

以前 openflow 一般的做法是：SDN controller 中有 app，app 根據DO(?)、邏輯 ，透過 openflow protocol 將 rule 下至 table。但都是假設 switch 中的 main interfere 是固定的（通常就是標準的 IPv4, IPv6），之後有人提出「那麼是否可以提出 P4 program 的組態，將 rule 透過編譯器下到 copy 到 switch 裡，此時就可以根據不同使用者自定義這個 switch 來接受不同格式（header 不同）的 packet 」，所以在 SDN 中，controller 對 switch 透過 openflow protocol 下 rule。switch 中會進入 ***pipeline*** 檢查 tag，***Vlan tag*** 是所有 switch 都會檢查的部份，其他 datagram 的部份，就看是哪個廠商的 switch，IC design 會決定需要檢查的有哪些。

### Now P4

在 P4 架構中 controller 下到 rule translator，switch 本身要給 API，target 就是 P4 switch。一般的 Switch，包含 SDN Switch 都只能夠處理現存協定之封包（IPv4等）。

透過 P4，開發者能夠直接定義出一個 switch 能夠處理的封包格式，舉例來說：定義一個新的 ethernet type，或是自行定義封包結構。另外，p4 switch 不被侷限現在特定的硬體之下執行，只需要有對應的編譯器就可以佈署，這部份之後會在說明。

* parser: 將分組 data 轉成 metadata

* match+action: 操作 metadata

* metadata: 在 pipeline 中的 data， control flow 結束後，就會被重置

  * > Packets can carry additional information between stages, called metadata, which is treated identically to packet header fields 

* P4 switch 中含有兩條 pipeline: ingress & egress；同時還有一些數據流管理功能，例如：擁塞控制，隊列控制，流量複製等。 

### Openflow SDN and P4 in common

#### Data Plane (P4) Program

* Defines the format of the table
  * Key Fields
  * Actions
  * Action Data
* Performs the lookup
* Executes the chosen action

#### Control Plane (IP stack, Routing protocols)

Populates table entries with specific information (based on the configuration, automatic discovery and protocol calculations)

## Packet 如何被 P4 處理 - Forwarding model

![](https://camo.githubusercontent.com/c0a689118891e31bfd379911a4d362eb81d07ac1/68747470733a2f2f7777772e657665726e6f74652e636f6d2f6c2f41533565564459775572524d7872723578426e767a566a476458337451522d44326945422f696d6167652e706e67)

1. 從 input port 進來，抵達封包首先被 parser 處理：辨認 ( *recognize* ) 並提取 ( *extract* ) packet header fields，不對 packet header 做任何假設，將結果放在 parser graph。packet 進來到s switch 就會依照 parser graph，抓出 match 的 header（怎麼抓硬體廠商要做的事）。

2. 提取出的 header fields會被傳到 match+action tables

3. Parser 處理完封包之後，會將相關的資料，例如解析出來的 header 以及 metadata 儲存，然後交由 ingress 處理：ingress 將封包送往不同的 table、更改封包 header 內容、設定封包輸出的 port 等等，最後再丟到一個 queue 中

   * match + aciton，跟 SDN 一樣也是 pipeline、multiple table，分成兩個部分：Ingress/Engress pipeline，不過不是一定得走 pipeline，如果有進來，我們可以對 packet 做修改(e.g by save field action)，也可以決定 egress 的 selection（決定 packet 要從哪個 port(s) 出去）。
   * Control progran:  寫 action, 宣告 table 組態。

## P4 工作流程

1. 定義 parser, flow，經 compiler 編譯後會輸出 json 格式的 switch 配置文件及對應的 API
2. 根據配置文件更新 parser 及 match+action table，然後查表操作

## Header Specification

> Packet forwarding behavior begins with the definition of the packet headers.  The header is defined as a list of fields of name-bit width pairs.
>
> A header definition describes the sequence and structure of a series of fields. It includes specification of field widths and constraints on field values.
>
> Each header is specified by declaring an ordered list of field names together with their widths. Optional field annotations allow constraints on value ranges or maximum lengths for variable-sized fields.

* 要宣告有哪些可用的 header，類型有兩種：**packet header** & **metadata**，主要差別是 valid bit
  * metadata 用來存數據和配置信息
    * User-Defined Metadata
      * To access queueing information: [queueing_metadata](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md#queueing_metadata-header)
    * Intrinsic Metadata，含 switch 本身的配置資料，e.g input port number
      * See BMv2 Simple Switch for example: https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md#intrinsic-metadata
    * **validity**: 
      * 在 parse 過程中被 extract
      * 在 match+action 時被操作，像是 add/copy
      * parent header 為 valid，child 必為 valid
      * metadata is *always* valid
    * **<u>Standard Metadata 使用與說明</u>**
      * 使用：`standard_metadata.fieldName`
      * fields
        * **ingress_port**：封包進來的 port，唯讀
        * **packet_length**：封包長度（byte），不包含 ethernet header CRC。如果 switch 開啟 cut-length 模式，則不能用在 match 中，也不能在 action 被參考；唯讀。
        * **egress_spec**：在 ingress control flow 中可以被設定，可以是實體 port、或是虛擬 port，或是 multicast 群組。
        * **egress_port**：真正實際要出去的實體 port，若 egress_spec 指向實體 port 就會相同，若是虛擬 port 則會轉換後寫在這邊，ingress 階段沒有讀取的意義。唯讀。
        * **egress_instance**：僅在 egress 中有意義，跟 egress_port 一樣是在中間的 buffer/queue 階段產生的資料。
           有這一份資料的目的是，當封包被複製（flood、multicast），則每一個封包都會有一個不同的 ID 以方便辨認。
        * instance_type
          1. normal：一般的
          2. ingress clone：透過 clone_i2i 或 clone_i2e 的方式產生的封包
          3. egress clone：透過 clone_e2i 或 c;one_e2e 的方式產生的封包
          4. recirculated：透過 resubmit 跟 recirculate 重送的封包
        * **parser_status**：0 表示 parser 沒有問題，否則就會是錯誤代碼。
        * **parser_error_location**：詳細的 parser 錯誤位置。
* header instance 與意義
  * 每個 header 類型都有對應的 header instance 來儲存具體的數據

  ```p4
  header headerTypeName headerInstanceName
  ```

  * 要給從 packets parse 出來的，header 為 headerTypeName 的 headerInstanceName， 資源，同時讓 instance 成為 parsed representation 的一部份，可以再後面 match action pipeline 中使用，或是直接引用，像是 `headerInstanceName.fieldName` 這個作法，就像 pointer 一樣。

- fixed length / variable length
  - 不定長字段計算方法：P4 通過對值為 "\*" 的字段的使用，來支持從 packet 中 parse 出不定長的 header instance。該值為"\*"的字段的寬度，可以通過由長度屬性說明的，按字節計數的首部總長推出。**字段寬度= (8 \*總長-其它定長字段寬度的總和) (單位：==bit==)**

* 語法

  ```p4
  // normal header
  header_type headerTypeName {
    fields{
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



## Packet Parser

> While the header defines various fields, the locations of these fields within a given packet may vary based on encapsulation.  The operation of mapping the received packet to the fields is defined by the parser definition.
>
> A parser definition specifies how to identify headers and valid header sequences within packets.
>
> underlying switch can implement a state machine that traverses packet headers from start to finish, extracting field values as it goes.
>
> Parsing **starts in the start state and proceeds until an explicit stop state is reached** or an unhandled case is en- countered (which may be marked as an error). Upon reaching a state for a new header, the state machine extracts the header using its specification and proceeds to identify its next transition. The extracted headers are forwarded to match+action processing in the back-half of the switch pipeline.

p4 不想要侷限執行平台，透過 parser 自定義 packet header，並讓 switch 可以執行。

P4 中 parser 採用 FSM 的設計思路，每個 parser method 都視為一種狀態。預期要先看到定義在 starter packet 的 header（`parser start{ packet }`），再根據 packet 的值決定下一個動作。當前處理的 packet header offset 會被記錄在 header instance，並在狀態遷移（調用另一個解析器）時指向 header 中下一個待處理的有效字節，每一個 parser 中都會依據目前所分析的內容來決定下一個 parser，直到回傳的內容為 "ingress"

**簡單來說：parser 都是以 start 方法開始，以ingress結束。**

- parser 結束方法可能有：

  * 1）***return defined parser***

  - 2）***return defined flow controller***, such as ingress 
  - 3）發生顯式錯誤 - parse error
  - 4）發生隱式錯誤

* 語法

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
    決定packet 接下來要到哪個 parser

  * `select`

    像c語言的 switch-case，依據特定的 field 數值去決定要哪一個 parser 或是 control function。

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

## Action Specification

> Actions specify the operations to be performed as a result of a table match.  The actions can update the PHV, manipulate stateful memories, and/or edit packet contents.
>
> P4 supports construction of complex actions from simpler protocol-independent primitives. These com- plex actions are available within match+action tables

* 如果 action 需要參數，要在 run time 的時候


* primitive actions

  source file: https://github.com/p4lang/behavioral-model/blob/master/targets/simple_switch/primitives.cpp
  json file: https://github.com/p4lang/p4-hlir/blob/master/p4_hlir/frontend/primitives.json

  * ***set_field***

    為特定 header field 設值

  * ***copy_field(dst, src)***

    顧名思義

  * ***add_header(headerInstance)***

    加入一個 Header，如果該 Header 已經存在，則不變。Header 預設都是零

  * ***remove_header(headerInstance)***

    從  packet 中移除指定 header （ 將 Header 標記為 invalid，也就是說他不會被封裝和 match 到）

  * ***modify_field(dst, value[, mask])***

    更改某一個特定值，其中 dst 可以是 header_inst.field 或是 register

  * ***add_to_field(dst, value)***

    將 value 加到 dst 中，其中 dst 可以是 header_inst.field 或是 register

  * ***add(dst, val1, val2)***

    講兩個數字相加後儲存

  * ***modify_field_with_hash_based_offset (dest, field_list_calc, base, size)***

    透過給定一個已經定好的 field list calc，去計算出 hash，並儲存到 dest 中。然後 hash 產生完之後，會在透過下面公式轉換：new_hash = base + hash_val % size

  * ***truncate(len)***

    將 Packet 在 **egress 階段**截短，其中 len 的單位為 byte。若 packet 長度比 len 短，則不會有影響。

  * ***drop()***

    在 **egress 階段**把 packet 扔掉。

  * ***no_op()***

    僅用於佔位，不會做任何事情。

  * ***push(array[, count])***

    將新的 Header push 到 Packet 中，舊的 Header 會保留在底層。array 是先定義好的 header array，count 預設為 1

  * ***pop(array[, count])***

    將 Packet header pop 到 array 中

  * ***generate_digest(receiver, field_list)***

    將特定欄位的資料傳送給 reciver，reciver 是一個數字，代表接收端，而接收端的定義不在 P4 的標準當中。

  * in ingress

    * ***resubmit([field_list])***

      將 Packet 重新送到 Parser 階段中

    * ***clone_ingress_pkt_to_ingress(clone_spec, [ field_list ] )***

      將目前的封包複製一份傳送回Parser，可縮寫成：clone_i2i

    * ***clone_ingress_pkt_to_egress***

      將目前的封包複製一份傳送到 Buffer 中，可縮寫成：clone_i2e

  * in egress

    * ***recirculate([field_list])***

      將 Packet 重新送到 Parser 階段中

    * ***clone_egress_pkt_to_ingress***

      將目前的封包複製一份傳送回Parser，可縮寫成：clone_e2i

    * ***clone_egress_pkt_to_egress***

      將目前的封包複製一份傳送到 Buffer 中，可縮寫成：clone_e2e

  * ***increment***

    增加/減少 field 的值

  * ***checksum***

    算多個 fields 的 checksum


* 語法

  ```p4
  //definition
  action actionName([paras]){
    //statements
  }
  ```


P4 假設 statement 循序執行（非平行執行）。

## Table Specification（定義 match field）

> Tables define the match key and actions performed on a packet.  The **match key comes from values extracted** with the parser and stored in the PHV.  The subsequent actions are passed on for further matching.
>
> Match+action tables are the mechanism for per- forming packet processing. The P4 program defines the fields on which a table may match and the actions it may execute.
>

P4 透過定義 table，讓有特定 packet header 的 packet ，做 programmer 指定的 action。***(apply action to a packet by the field)***

### 定義和應用方式

> Tables are defined and applied with the following conventions:
>
> *  Header references for matching may only be used with the valid match type.
> *  Exactly one of the actions indicated in either the `action_specification` or the `action_profile_specification` will be run when a table processes a packet.
>   * Entries are inserted at run time and each rule specifies the single action to be run if that entry is matched.
>   * Actions in the list may be primitive actions or compound actions.
> *  At run time, the table entry insert operation (not part of P4) must specify:
>   * Values for each field specified in the reads entry.
>   * The name of the action from the `action_specification` or the `action_profile_specification` and the parameters to be passed to the action function when it is called.

* 語法

  ```p4
  table  tableName {
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
      * <u>*exact*</u> : field value 必須跟 table entry value 一模一樣 
      * *ternary* : 用給定的 mask match
      * <u>*lpm*</u> : ( longest prefix match ) termary match 的特例，通常用在 IP match，如 140.113.0.0/16
      * *range* : 只要 value 落在區間就可以 
      * *valid* : header_field 有被成功 parse ，就算是 valid
    * `actions`: match 成功後**可能要做的**（ 不是寫了就要做）的 action，所以可以有多個，確切要做什麼是看 rule 怎麼下。
    * size

        * `min_size`: table 最少要有幾個 entries 符合，否則會有 error 出現
        * `max_size`: entries 最大數量，超過這個數量，table 不再執行 action （ table 可以 support 的最大 entries 數量）
        * `size`: 符合特定 size 才會運作 -> 可以理解程 table entry 的個數
        * 沒有特別指定， compiler 會幫設個 default 值
    * `support_timeout`: 就是是否自動 timeout


###Action Profile

> *According to spec p54, slide p90*
>
> Action profiles are declarative structures specifying a list of potential actions, and possibly other
> attributes. In the case of that action parameter values are not specific to a match entry but could
> be shared between different entries. Some tables might even want to share the same set of action parameter values.
>
> ***dynamic_action_selection***: Instead of statically binding one particular action profile entry to each match entry,one might want to associate multiple action profile entries with a match entry and let
> the system (i.e., data plane logic) dynamically bind one of the action profile entries to each class of packets
>
> * Separate table match entries from actions and action data
> * Allow multiple entries to share same action data
>   * Saves space
>   * Allows quick update of multiple entries
> * Allow multiple actions/action_data per entry
>   * This is called "dynamic action selection"
>   * Used to implement LAG or ECMP
> * Can be more efficient compared to explicit implementation

* 語法

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


## Control Program (flow control)
> The control flow ties all the P4 components together into a packet processing **pipeline flow**.  Separate control flows are defined for **ingress and egress processing** where the packet buffer and packet replication sits in between the ingress and egress.
>
> The control program determines the order of match+action tables that are applied to a packet. A simple imperative program describe the flow of control between match+action tables.
>
> Once tables and actions are defined, the only remaining task is to specify the flow of control from one table to the next. Control flow is specified as a program via a collection of functions, conditionals, and table references.
>
> In short, you can 
>
> * apply packet to specific tables
> * go to other control flows

***ingress 和 egress control flow 分別代表了一個封包的進入以及離開。***

* ***ingress*** 決定 egress port 和 packet 要放到哪個 queue 中，過程中可能
  * Modify state (register)
  * Modify packet
  * Modify metadata
  * Modify egress_spec (e.g. queue, output port)
    *  `modify_field(standard_metadata.egress_spec, 1)`;
    *  不一定只是個 port 而已，也能是個 route 或是 multicast group 等，而這些東西都會事先於 switch 中先定義好。

  最後可能 

  * forwarded 
  * replicated
  * dropped
  * trigger control flow

**一般來說，一個 ingress 執行完畢之後，會將處理過的封包資料傳送到 queue ，等待 egress 階段，但如果在 action 當中呼叫了像是 resubmit 或是 recirculate 等 API，則會在階段完成之後將封包送回 ingress 重新處理，或是呼叫 clone_e2i 之類的 API 也會複製一份封包，在處理階段完成後送到指定的地方。**

* ***egress*** 將 Queue 的資料拿出來，再次處理 (modify) 並且將封包送出、丟棄、複製或是重新處理（recirculate）
  * 可以透過 standard_metadata 取得 egress_port 這一個值（唯讀）來判斷要做什麼事情。
  * The packet is regenerated based on the updated PR header instances.


* 語法

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
    apply(tableName){
        action_case{
            action_or_default
        }
    }
    ```

    依據該 table 選到的 action 去決定要執行哪一段 control block

## Others

* Stateful object

  > Keep the state for each packet

  * Counters are incremented with each packet
  * Meters keep their bucket state
  * Registers store arbitrary data

* stateless object

  > They are re-initialized for each packet (control flow 結束後)

  * metadata
  * packet headers

packet 及 metadata instance data 只能存在某個 parsed packet，parse 下個 packet 的時候，instance 會初始化，不過有 counter,meter & register 在整個 pipeline 可以長期存在。

### counter

> Counters can be used to measure the packet rate each host generates (possibility of DoS), the number of unsuccessful connection attempts (possibility of portscan, or Syn flood), or the number of bytes the host transferred

* 語法

  ```p4
  counter counter_name {
      type : packets | bytes;
      [direct : table_name;| static : table_name;]
      [instance_count : const_value;]
      [min_width : const_value;]
      [staturating;]
  }

  // 更新計數器，將計數器的數值加一，index 參數表示 counter array 的 index（只適用在 static counter 上）
  action action_name(whom_to_set, counter_stat_index) {
    count(counter_ref, index);
  }
  ```

  * **type** 

    顧名思義就是 Counter 的類型，依據設定使用不同的方式來統計，在 P4 當中可以使用 packet 以及 byte 兩種。

    （若沒有指定 static 或 direct，任一 table 都可透過 count  action 來增加此 counter 的數值）

  * **direct**

    指定的 table 中所有的 entry 都會套用這一個 counter，也就是說這一個 counter 不能被 count 這一個 action 呼叫，否則會出現錯誤；不管有沒有 match，每個 entry 都會有一個 counter 

  * **static**

    指定的 table 中可以使用 count 這一個 action 來增加 counter 中的內容，但是如果被其他的 table 呼叫，則會出現錯誤。

  * **instance_count**

    用來配置這一個 counter 的實體數量，要注意的是，當一個 Counter 具有 direct 屬性時，則這一個屬性將不會存在，否則他就是必要的屬性。

  * **min_width**

    指定這一個 counter 的最小大小（單位：bits）

  * **staturating**

    若有寫這一個屬性，則在 counter 抵達上限時時候將會停止計數，否則將會歸零。

* example

  ```p4
  counter packets_by_source_ip {
  	type: packets;
  	direct: ip_host_table;
  }
  ```

### meter

> 類似 counter ，但評估的是 packet rate 而非 packet/byte count

* 語法

  ```p4
  meter meter_name {
      type : bytes | packets;
      result : field_ref;
      [direct : table_name;]
      [static : table_name;]
      [instance_count : const_value;]
  }

  action action_name(meter_index) {
    execute_meter(meter_ref, index, field);
  }
  ```

  type、direct、static 以及 instance_count 與 counter 相同，唯一不同的是 result。

  result：指定一個 field（如 metadata 中的資料）來儲存資料。

### register

> 像 ***global*** variable，存 data；可用來設計 stateful dataplane 

* 語法

  ```p4
  register register_name {
      width : const_value; | layout : header_type_name;
      [direct : table_name;]
      [static : table_name;]
      [instance_count : const_value;]
      [attribute_list;]
  }

  // use
  register_name[ const_value ]
  register_name[ const_value ].field_name

  // actions
  register_read(register_array, register_index, destination_field);
  register_write(register_array, register_index, value);
  ```

  layout 則是直接套用一個定義好的 header 結構。

  direct、static、instance_count 也是跟前兩個相同。

  attribute_list 的定義如下：attributes : entry , entry ,...每一個 entry 可以是 signed 或是 staturing。


### metadata

> 像 local variable，一個 control flow 結束後，就會被 reset

### field_list

讓處理過程變得更加方便，如 hash function 中，可以把 field list 當作函數輸入，根據此 list 計算 checksum

```p4
field_list listName {
  instanceName.headerField;
  ...
}
```

### Auto-generated PD API

> A set of protocol dependent API is auto-generated from the P4 code as part of the compilation processes.  These API provide a consistent set of primitives to manipulate data structures as defined within the P4 code.  The header file for the API can be found in build/inc/p4_sim/pd.h after compilation of the behavioral model.

A sample set of the auto-generated API is shown below:
```p4
bf_pd_status_t bf_pd_dc_full_ipv4_fib_table_add_with_fib_hit_nexthop( bf_pd_sess_hdl_t sess_hdl, bf_pd_dev_target_t dev_tgt, bf_pd_dc_full_ipv4_fib_match_spec_t *match_spec, bf_pd_dc_full_fib_hit_nexthop_action_spec_t *action_spec, bf_pd_entry_hdl_t *entry_hdl );
bf_pd_status_t bf_pd_dc_full_ipv4_fib_table_delete ( bf_pd_sess_hdl_t sess_hdl, uint8_t dev_id, bf_pd_entry_hdl_t ent_hdl  );
bf_pd_status_t bf_pd_dc_full_ipv4_fib_table_modify_with_fib_hit_ecmp ( bf_pd_sess_hdl_t sess_hdl, uint8_t dev_id, bf_pd_entry_hdl_t entry_hdl, bf_pd_dc_full_fib_hit_ecmp_action_spec_t *action_spec );
bf_pd_status_t bf_pd_dc_full_ipv4_fib_set_default_action_on_miss ( bf_pd_sess_hdl_t sess_hdl, bf_pd_dev_target_t dev_tgt, bf_pd_entry_hdl_t *entry_hdl );
```


# P4_16

## Header Data Types

### Basics

* ***bit\<n>***: Unsigned integer of length n, bit == bit\<1>
* ***int\<n>***: Signed integer of length n >= 2
* ***varbit\<n>***: variable length bitstring

### Derived

* ***header***
  * Byte-aligned
  * valid/invalid
  * Can contain basic types
* ***struct***: array of headers
* ***typedef***: alia of another type

### Example

```p4
typedef bit<48> mac_addr_t;

header ethernet_t {
  bit<48> dstAddr;
  //or mac_addr_t dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

header vlan_tag_t {
  bit<3> pri;
  bit<1> cfi;
  bit<12> vid;
  bit<16> etherType;
}

struct my_headers_t {
  ethernet_t ethernet;
  vlan_tag_t[2] vlan_tag;
}

header ipv4_options_t {
  varbit<320> options;
}
```

## Declaring and Initializing Variables

```p4
bit<16> my_var;
bit<8> another_var = 5;

const bit<16> ETHERTYPE_IPV4 = 0x0800; //Better than #define!
const bit<16> ETHERTYPE_IPV6 = 0x86DD;

ethernet_t eth;
vlan_tag_t vtag = { 3w2, 0, 12w13, 16w0x8847 }; //Safe constants with explicit widths
```

## Parser

```p4
parser MyParser(packet_in               packet
                out   my_headers_t      hdr
                inout my_metadata_t     meta
                inout standard_metada_t standard_metadata)
{
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x8100 &&& 0xEFFF : parse_vlan_tag;
      0x0800 : parse_ipv4;
      0x86DD : parse_ipv6;
      0x0806 : parse_arp;
      default : accept;
    }
  }

  state parse_vlan_tag {
    packet.extract(hdr.vlan_tag.next);
    transition select(hdr.vlan_tag.last.etherType) {
      0x8100 : parse_vlan_tag;
      0x0800 : parse_ipv4;
      0x86DD : parse_ipv6;
      0x0806 : parse_arp;
      default : accept;
    }
  }

  state parse_ipv4 {
    packet.extract(hdr.ipv4);
    transition select(hdr.ipv4.ihl) {
      0 .. 4: reject;
      5: accept;
      default: parse_ipv4_options;
    }
  }

  state parse_ipv4_options {
    packet.extract(hdr.ipv4.options,
                   (hdr.ipv4.ihl - 5) << 2);
    transition accept;
  }

  state parse_ipv6 {
    packet.extract(hdr.ipv6);
    transition accept;
  }
}
```

## Controls, table & actions
> if() statements are allowed in actions too!

### Standard Arithmetic and Logical operations
* +, -, *
* ~, &, |, ^, >>, <<
* ==, !=, >, >=, <, <=
* **No division/modulo**

```p4
const bit<9> DROP_PORT = 511; /* Specific to V1 architecture */

action mark_to_drop() { /* Already defined in v1model.p4 */
  standard_metadata.egress_spec = DROP_PORT;
  standard_metadata.mgast_grp = 0;
}

control MyIngress(
  inout my_headers_t        hdr,
  inout my_metadata_t       meta,
  inout standard_metadata_t standard_metadata
{
  /* Local Declarations */
  action swap_mac(inout bit<48> dst, inout bit<48> src) {
    bit<48> tmp;
    tmp = dst; dst = src; src = tmp;
  }

  action reflect_to_other_port() {
    standard_metadata.egress_spec = standard_metadata.ingress_port ^ 1;
  }

  bit<48> tmp;
  apply {
    /* Can also do assignment directly */
    if (hdr.ethernet.dstAddr[40:40] == 0x1) {
      mark_to_drop();
    } else {
      swap_mac(hdr.ethernet.dstAddr, hdr.ethernet.srcAddr);
      reflect_to_other_port();
    }
  }
}
```

### Actions Galore: Operating on Headers
* Header Validity bit manipulation
  ```p4
  header.setValid();   // add_header
  header.setInvalid(); // remove_header
  header.isValid();
  ```

* Header Assignment
  ```p4
  header = { f1, f2, ..., fn }
  header1 = header2
  ```
* Special operations on Header Stacks
  * In the parsers
    * `header_stack.next`
    * `header_stack.last`
    * `header_stack.lastIndex`
  * In the controls
    * `header_stack[i]`
    * `header_stack.size`
    * `header_stack.push_front(int count)`
    * `header_stack.pop_front(int count)`
### Actions Galore: Bit Manipulation
  * Bit-string concatenation
    ```p4
    action set_ipmcv4_mac_da_1() {
      hdr.ethernet.dstAddr = 24w0x01005E ++ 1w0 ++ hdr.ipv4.dstAddr[22:0];
    }
    ```
  * Bit-slicing
    Usage: `header.field[msb:lsb]`
    ```p4
    action set_ipmcv4_mac_da_2() {
      hdr.ethernet.dstAddr[47:24] = 0x01005E;
      hdr.ethernet.dstAddr[23:23] = 0;;
      hdr.ethernet.dstAddr[22:0] = hdr.ipv4.dstAddr[22:0];
    }
    ```

### Match-Action Table

Defines

* What to match on and match type
* A list of possible actions
* Additional properties
  * size
  * Default action
  * entries
* Each table contains one or more entries
  * An entry contains
    * A specific key to match on
    * A single action
    * (Optional) action data

1. Define Actions
  * Actions can use two types of parameters
    * Directional (from the Data Plane)
      * Actions that are called directly **can only** this kind
    * Directionless (from the Control Plane)
  * Actions used in tables:
    * Typically use direction-less parameters
    * May sometimes use directional parameters too
  * P4_16 has typecasts: `(bit<16>)ecmp_group`

  ```p4
    action l3_switch(bit<9> port,
                     bit<48> new_mac_da,
                     bit<48> new_mac_sa,
                     bit<12> new_vlan)
    {
      /* Forward the packet to the specified port */
      standard_metadata.metadata.egress_spec = port

      /* L2 Modifications */
      hdr.ethernet.dstAddr = new_mac_da;
      hdr.ethernet.srcAddr = mac_sa;
      hdr.vlan_tag[0].vlanid = new_vlan;

      /* IP header modification (TTL decrement) */
      hdr.ipv4.ttl = hdr.ipv4.ttl – 1;
    }

    action l3_l2_switch(bit<9> port) {
      standard_metadata.metadata.egress_spec = port;
    }

    action l3_drop() {
      mark_to_drop();
    }
  ```

2. Define table

   ```p4
   table ipv4_host {
     key = {
       meta.ingress_metadata.vrf: exact;
       hdr.ipv4.dstAddr         : exact;
     }
     actions = {
       l3_switch;  l3_l2_switch;
       l3_drop;    noAction;
     }
     default_action = noAction(); // Defined in core.p4
     size = 65536;
   }
   ```

3. Using Tables in the Controls (***Important Example***)
   ```p4
    control MyIngress(inout my_headers_t
                      hdr,
                      inout my_metadata_t
                      meta,
                      inout standard_metadata_t standard_metadata)
    {
      /* Declarations */
      action l3_switch(...) {...}
      action l3_l2_switch(...) {...}
      ...
      table assign_vrf {...}
      table ipv4_host {...}
      table ipv6_host {...}

      apply {
        assign_vrf.apply(); // Apply() Tables – Perform Match-Action
          if (hdr.ipv4.isValid()) { // Make sure the table matches on valid headers
            ipv4_host.apply();
          }
      }

      apply {
        ...
        if (hdr.ipv4.isValid()) {
          if (!ipv4_host.apply().hit) { // Apply method returns a boolean, representing the hit
            ipv4_lpm.apply();
          }
        }
      }

      apply {
        ...
        /**********************************************
          Switch() statement
          - Only used for the results of match-action
          - Each case should be a block statement
          - Default case is optional

          Exit and Return Statements
          - return – go to the end of the current control
          - exit – go to the end of the top-level control
          - Useful to skip further processing
        **********************************************/
        switch (ipv4_lpm.apply().action_run) {
          l3_switch_nexthop: { nexthop.apply(); }
             l3_switch_ecmp: { ecmp.apply(); }
                    l3_drop: { exit; } //
                    default: { /* Not needed. Do nothing */ }
        }
      }
   ```

## Packet Deparsing
See more details on page 97 of v1 spec.
```p4
  // Expressed as another control function - normal one
  control MyDeparser(packet_out packet,
                             in my_headers_t hdr)
  {
    apply {
      /* Layer 2 */
      packet.emit(hdr.ethernet);
      packet.emit(hdr.vlan_tag);

      /* Layer 2.5 */
      packet.emit(hdr.mpls);

      /* Layer 3 */
      packet.emit(hdr.arp);
      packet.emit(hdr.arp_ipv4);
      packet.emit(hdr.ipv4);
      packet.emit(hdr.ipv6);

      /* Layer 4 */
      packet.emit(hdr.icmp);
      packet.emit(hdr.tcp);
      packet.emit(hdr.udp);
    }
  }

  // Simplified Deparsing
  struct my_headers_t {
    ethernet_t     ethernet;
    vlan_tag_t [2] vlan_tag;
    mpls_t     [5] mpls;
    arp_t          arp;
    arp_ipv4_t     arp_ipv4;
    ipv4_t         ipv4;
    ipv6_t         ipv6;
    icmp_t         icmp;
    tcp_t          tcp;
    udp_t          udp;
  }

  control MyDeparser(packet_out packet,
                in my_headers_t hdr)
  {
    apply {
      packet.emit(hdr); // Headers will be deparsed in struct order
    }
  }
```

# P4 playground

## P4 repositories

* [p4c-bm](https://github.com/p4lang/p4c-bm) a.k.a p4c-bmv2
  * behavioral modal 的後端編譯器，建立在 p4-hlir 的頂部，該模塊以P4程序作為輸入，輸出一個可以載入到 behavioral model 的 json 配置文件。
* [behavioral-model](https://github.com/p4lang/behavioral-model) a.k.a bmv2
  * 模擬 P4 switch （ 即 ***P4 target*** ）， C++ 寫的
  * p4c-bm 將 P4 program 編譯成 json 格式的配置文件，並將之載入到 bmv2，轉化成能實現 switch 功能的數據結構
* [p4-hlir](https://github.com/p4lang/p4-hlir)
  * 前端編譯器
  * Translates P4 code to High-Level Intermediate Representation (HLIR)
* [p4factory](https://github.com/p4lang/p4factory)
  * 內含整套用以運行和開發基於behavioral model的P4程序環境的代碼，幫助用戶快速開發P4程序。

## Modular Compiler
![modular.png](https://i.imgur.com/8R4z3Dl.png)
Single Front-End (p4-hlir) + Multiple backends.
Backends involve
* Code generators for various targets, e.g. Software Switch Model (p4c-bm)
* Validators and graph generators
* Run-time API generators

## Set up required environment

* pip - python package manager
* mininet - simulate network environment
* Python packages: scapy, thrift (>= 0.9.2) and networkx
```shell
sudo apt-get install python-pip
sudo apt-get install mininet
sudo pip install scapy thrift networkx
```

## mininet

> 透過Mininet，只需要一行指令就可建立所需要的虛擬網路環境。Mininet可以很輕易的指定要多少台host、網路拓樸的型態、拓樸的深度、連接外部controller等。使用者還可以透過Python編寫環境的建置流程及控制虛擬環境內部設備，是一個自由度很高的虛擬環境。
>
> 用來模擬 OpenFlow Switch 的環境 -> 才有辦法開發 SDN（SDN run 在 Openflow protocol 上）
> Ref: https://seannets.wordpress.com/2016/04/19/學習sdn-準備工作-安裝mininet-and-ryu/

### 啟動與測試方法

在 terminal 中輸入

```shell
#Defaully create 2 hosts and 1 switch
sudo mn # Mininet must run as root

mininet >
help 
net 看網路 topology
nodes 看節點
dump 節點訊息
iperf tcp 測試
dpctl
noecho 運行交互窗口，關閉回應
pingall
h? ping h?
h? ifconfig
py python 程式
sh shell 程式
```

wireshark ping icmp

### 語法

* 驗證語法正確性

```shell
p4-validate _p4Programm_
```

## [bmv2](https://github.com/p4lang/behavioral-model)

> **a P4 software switch.** The 2nd version of the behavioral model. It is a C++ software switch that will behave according to your P4 program

Documentation: http://104.236.137.35/

targets

* [simple_router](https://github.com/p4lang/behavioral-model/tree/master/targets/simple_router)
  * smallest and simplest one, easy to get started
* [l2_switch](https://github.com/p4lang/behavioral-model/tree/master/targets/l2_switch)
  * introduces some additional complexity by including a packet replication engine (to support multicast)
* [simple_switch](https://github.com/p4lang/behavioral-model/tree/master/targets/simple_switch)
  * the standard P4 target and although it includes a lot of functionality
  * the code is still relatively small and straightforward

```shell
# install
git clone https://github.com/p4lang/behavioral-model.git bmv2

# install dependencies
./install_deps.sh 

# build the code
./autogen.sh
./configure
make
```

## [p4c-bmv2](https://github.com/p4lang/p4c-bm)
> **The reference P4 compiler**. The compiler for the behavioral model: it takes P4 program and output a **JSON** file which can be loaded by the behavioral model 

```shell
# install
git clone https://github.com/p4lang/p4c-bm.git p4c-bmv2

# install required Python dependencies
sudo pip install -r requirements.txt

# 
sudo python setup.py install
```

#### thrift-port

> 網路中 switch 的接口。runtime 階段可以使用這個接口來命令不同的 switch 做不同的事情。
> ***P4 中預設為 9090***

## [p4-hlir](https://github.com/p4lang/p4-hlir)
> p4-hlir translates P4 code to ***HLIR***(**H**igh-**L**evel **I**ntermediate **R**epresentation),
> which is similar to Abstract Syntax Trees (AST).

* Currently represented as a hierarchy of Python objects and only support P4_14
* Frees backend developers from the burden of syntax analysis and target-independent semantic checksi
* HLIR documentation is supplied with the frontend code

### 使用工具與方法
* 驗證 P4_14 語法
  ```shell
  p4-validate <path_to_p4_program>
  ```
* 使用 Python interacitve shell 來存取 HLIR instances
  ```
  # Method 1 - Use built HLIR
  p4-shell <path_to_p4_program>

  # Method 2 - Manually build HLIR
  python
  >>> from p4_hlir.main import HLIR
  >>> h = HLIR(<path_to_p4_program>)
  >>> h.build()
  ```

  用完上面其中一個方法後，在 Python Interactive mode 中可以透過以下存取 instances
  ```python
  h.p4_actions
  h.p4_control_flows
  h.p4_headers
  h.p4_header_instances
  h.p4_fields
  h.p4_field_lists
  h.p4_field_list_calculations
  h.p4_parser_exceptions
  h.p4_parse_value_sets
  h.p4_parse_states
  h.p4_counters
  h.p4_meters
  h.p4_registers
  h.p4_nodes
  h.p4_tables
  h.p4_action_profiles
  h.p4_action_selectors
  h.p4_conditional_nodes
  h.p4_ingress_ptr
  h.p4_egress_ptr
  ```
* 產生 P4_14 Table graph/parse graph AST png 檔案與表示其關係的 dot 檔
  ```shell
  p4-graphs <path_to_p4_program>
  ```
## How to run p4 program

1. 用 `p4c-bmv2` 產生 `.json` 給  `bmv2`  ，讓 `bmv2` 配置環境中的 switch

   ```shell
   p4c-bmv2 <path_to_source_P4_file> --json <output_JSON_file_with_path>
   ```

2. Start the switch with desired topology

   ```shell
   # Start the switch first if you need to enable debugger
   #<iface0> and <iface1> are the interfaces which are bound to the switch (as ports 0 and 1).
   $SWITCH_PATH [-i 0@<iface0> -i 1@<iface1>] [--nanolog] [--debugger] [--no-p4] <JSON_for_switch>
   # interfaces usage example: $SWITCH_PATH -i 0@veth0 -i 1@veth2

   # Use simple topology
   sudo python bmv2/mininet/1sw_demo.py --behavioral-exe $SWITCH_PATH --json <JSON_for_switch>
   ```

   Self-defined topology, e.g.
   * https://github.com/TakeshiTseng/2016-nctu-p4-workshop/blob/master/overlay/topology.py
   * https://github.com/TakeshiTseng/2016-nctu-p4-workshop/blob/master/stateful-example/topology.py
   * https://github.com/p4lang/tutorials/blob/master/SIGCOMM_2015/source_routing/topo.py

3. Add table entries to the switch using runtime CLI
   * Supported CLI commands: See all by starting runtime_CLI.py and press <TAB>
     ```
     table_set_default <table name> <action name> <action parameters>
     table_add <table name> <action name> <match fields> => <action parameters> [priority]
     table_delete <table name> <entry handle>
     ```
   * Start CLI
     ```shell
     # Interative mode
     $CLI_PATH [--json <JSON_for_switch>] [--thrift-port <port>]
     # Input mode with a input file including adding entries commands
     $CLI_PATH [--json <JSON_for_switch>] [--thrift-port <port>] < commands.txt
     # Or add one entry at a time using "echo"
     echo "<action>" | $CLI_PATH [--json <JSON_for_switch>]
     ```

4. Debugger

   use [tools/p4dbg.py](https://github.com/p4lang/behavioral-model/blob/master/tools/p4dbg.py) 

   ```python
   sudo ./p4dbg.py [--thrift-port <port>]
   ```

## Examples

# 相關主題
## Flowlet

# 其他

* [tutorials](https://github.com/p4lang/tutorials.git): See more examples and exercise here
* xterm setings
```
xterm -fa Monospace -fs 12

```
* TODO
- [ ] how to use debugger
- [ ] event log tool
- [ ] other tools

### scapy

* Communication commands: [sniff](http://xiaix.me/python-shi-yong-scapy-jin-xing-zhua-bao/)
* Scapy doc: http://www.secdev.org/projects/scapy/files/scapydoc.pdf


### Run P4 on the machine of lab215 - Vagrant

* https://gogojimmy.net/2013/05/26/vagrant-tutorial/

自動化虛擬機的安裝和配置過程，如開機、安裝 MySQL、網路環境配置、主機與虛擬機間的文件共享等，配合 *Vagrantfile* 使用。Vagrant 視虛擬機為「Provider」、映像檔（ Image ）為「Box」

* 常用指令

  ```shell
  # vagrant box
  vagrant box list
  vagrant box add <Box name> <Download url or box file> # Decide OS on th
  vagrant box remove
  # 初始化 Box，產生 Vagrantfile
  vagrant init
  # 開機
  vagrant up
  # 休眠
  vagrant suspend
  # 取消休眠
  vagrant resume
  # 關機
  vagrant halt
  # 重新開機
  vagrant reload
  # 以完整的配置開機
  vagrant provision
  # ssh 到虛擬主機
  vagrant ssh
  vagrant ssh-config
  # 停止虛擬機運作並銷毀所有資源
  vagrant destroy
  # 環境打包
  vagrant package
  # 看狀態
  vagrant status
  vagrant global-status
  ```

