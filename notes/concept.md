P4 概念
===

## P4 語言的目標
* Reconfigurability
  * 希望透過 P4 program 就能更改 parser，來決定 target switch 的 pipeline、table、match 和 actions
  * P4 compiler 採用了模組化的設計，各模組都有 configurality，像是 p4c-bm 的輸出為 bmv2 的輸入
* Protocol Independence
  * 硬體設備不應該被 protocol 限制
* Target Independence
  * 不希望限制特定的執行平台，希望各式各樣的 switch，甚至網卡和 software switch 都能運行

## Switch 的結構演變

以前 openflow 的做法是：SDN controller 基於 openflow protocol 將 rule 下至 table；  
但都是假設 switch 中的 main interfere 是固定的（通常就是標準的 IPv4, IPv6），之後有人提出  
「那麼是否可以提出 P4 program 的組態，將 rule 透過編譯器 copy 到 switch 裡，  
此時就可以根據不同使用者自定義這個 switch 來接受不同格式（header 不同）的 packet 」

透過 P4，開發者能夠直接定義出一個 switch 能夠處理的封包格式，比如說：定義一個新的封包結構。

## Abstract Forwarding Model

![Abstract Forwarding Model](https://camo.githubusercontent.com/c0a689118891e31bfd379911a4d362eb81d07ac1/68747470733a2f2f7777772e657665726e6f74652e636f6d2f6c2f41533565564459775572524d7872723578426e767a566a476458337451522d44326945422f696d6167652e706e67)

- *Parser Graph*
  - ***P4 models the parser as a state machine.***  
    This can be represented as a *parse graph* with each state a node and the state transitions as edges.
  - switch 根據 parser graph 抓出 match 的 header
- parser 對每個封包辨認 ( *recognize* ) 並提取 ( *extract* ) packet header fields，接著產生用於 *match+action table* 的 *Parsed Representation*，  
  並進入 *Ingress Pipeline*
  - ***可以把 Parsed Representation 看作提取出的 header/metadata fields***
- *Ingress Pipeline*
  - 封包被送往不同的 table，可能會被更改或只是單純設定 output port 等
  - Pipeline 中的 match+action tables 產生 *Egress Specification*，用來決定封包要送往哪個（些）port(s)
  - 處理結束後送往 *Queue Buffer*
- *Queuing Mechnism* 處理 *Egress Specification*，產生 packet instances 接著送到 *Egress Pipeline*
- 進到 *Egress Pipeline* 前，封包的目的地已經被決定（ **it's assumed not to change in Egress Pipeline** ）
- 當 *Egress Pipeline* 處理完， *Parsed Representation* 組成了 packet instance 的 header

## P4 Abstractions

- Header Instance：packet header 或 metadata 的 instance
  - Metadata
  - Header stack：由 header instances 組成的連續 array
  - Dependent fields：欄位值由其他欄位或常數計算得出
- For a parser
  - Value set：用來決定 parse state function （定義封包裡的 header）的 run-time updatable values 
  - Checksum calculations：對封包的一些 bytes 做 checksum 運算來測試是否符合 field 的要求

## 工作流程

- 定義 parser, flow，經 compiler 編譯後會輸出 json 格式的 switch 配置文件及對應的 API

- 根據配置文件更新 parser 及 match+action table，然後查表操作

- parser: 將分組 data 轉成 metadata

- match+action: 操作 metadata

- metadata: 在 pipeline 中的 data， control flow 結束後，就會被重置

  - > Packets can carry additional information between stages, called metadata, which is treated identically to packet header fields

- P4 switch 中含有兩條 pipeline: ingress & egress；同時還有一些數據流管理功能，例如：congestion control

## Header and fields



> Packet forwarding behavior begins with the definition of the packet headers.  
> The header is defined as a list of fields of name-bit width pairs.
>
> A header definition describes the sequence and structure of a series of fields.  
> It includes specification of field widths and constraints on field values.
>
> Each header is specified by declaring an ordered list of field names together with their widths.  
> Optional field annotations allow constraints on value ranges or maximum lengths for variable-sized fields.



## Packet Parser

> While the header defines various fields, the locations of these fields within a given packet may vary based on encapsulation.  
> The operation of mapping the received packet to the fields is defined by the parser definition.
>
> A parser definition specifies how to identify headers and valid header sequences within packets.
>
> Underlying switch can implement a state machine that traverses packet headers  
> from start to finish, extracting field values as it goes.
>
> Parsing **starts in the start state and proceeds until an explicit stop state is reached**  
> or an unhandled case is en- countered (which may be marked as an error).  
> Upon reaching a state for a new header, the state machine extracts the header  
> using its specification and proceeds to identify its next transition.  
> The extracted headers are forwarded to match+action processing in the back-half  
> of the switch pipeline.

Parser 採用 FSM 的設計思路，每個 parser method 都視為一種狀態。  
看到定義在 starter packet 的 header（`parser start`），接著才根據 packet 的值決定下一個動作。  
當前處理的 packet header offset 會被記錄在 header instance，  
並在 state transition 時（使用另外一個 parser method）指向 header 中下一個待處理的有效區段，  
每個 parser 中都會依據目前所 parse 的內容來決定下一個 parser，直到回傳的內容為 "ingress"

**小總結：parser 以 start 開始，以 ingress 結束。**

## Action Specification

> Actions specify the operations to be performed as a result of a table match.  The actions can update the PHV, manipulate stateful memories, and/or edit packet contents.
>
> P4 supports construction of complex actions from simpler protocol-independent primitives. These com- plex actions are available within match+action tables

## Table Specification

> Tables define the match key and actions performed on a packet.  The **match key comes from values extracted** with the parser and stored in the PHV.  The subsequent actions are passed on for further matching.
>
> Match+action tables are the mechanism for per- forming packet processing. The P4 program defines the fields on which a table may match and the actions it may execute.
>

P4 透過定義 table（也就是定義 match field），讓有特定 packet header 的 packet ，做 programmer 指定的 action。

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

**一般來說，一個 ingress 執行完畢之後，會將處理過的封包資料傳送到 queue ，等待 egress 階段，但如果在 action 當中呼叫了像是 resubmit 或是 recirculate 等 API，則會在階段完成之後將封包送回 ingress 重新處理，或是呼叫 `clone_e2i` 之類的 API 也會複製一份封包，在處理階段完成後送到指定的地方。**

* ***egress*** 將 Queue 的資料拿出來，再次處理 (modify) 並且將封包送出、丟棄、複製或是重新處理（recirculate）
  * 可以透過 standard_metadata 取得 egress_port 這一個值（唯讀）來判斷要做什麼事情。
  * The packet is regenerated based on the updated PR header instances.


* 語法


## Others

### Stateless or Stateful

* Stateful objects：不隨 pipeline 改變而被初始化，可以長期存在
  * Counters
  * Meters
  * Registers
  * 單一個 counter/meter/register 都在 spec 中被稱為 *cell*，  
    同樣類別的 objects 就組成 cells ，cells 再組成 arrays；  
    會在 table 中的 action 以 array name 或 index 來存取或更新 cell，
* Stateless objects：會在 pipeline 結束後被初始化

  * metadata
  * packet headers

### Counter

藉由統計 packet/byte counts 來評估每個 host 產生的封包數量、失敗連線的嘗試次數、傳送的 bytes 數等

### Meter

類似 couter，不過是保存 bucket 狀態，評估 data rate，會以編碼來表示結果為三個顏色紅黃綠哪一個（*meter result*）

### Register

像 ***global*** variable，可存任意 data；  
可用來設計 stateful dataplane，如辨認不同 flow 的 "first packet"，之後同 flow 的封包就可以存在 register 裡

### field_list

讓處理過程變得更加方便，如 hash function 中，可以把 field list 當作函數輸入，根據此 list 計算 checksum

```p4
field_list listName {
  instanceName.headerField;
  ...
}
```

## Examples

# 相關主題
## Flowlet

## 相關工具

###  tutorials

到 p4lang 的 [tutorials](https://github.com/p4lang/tutorials.git) 可以找到更多範例及相關資源

### xterm

- 設定

  ```shell
  xterm -fa Monospace -fs 12
  ```

* TODO
- [ ] how to use debugger
- [ ] event log tool
- [ ] other tools

### scrapy

* [Scapy documentation](http://scapy.readthedocs.io/en/latest/index.html)
* Communication commands: [sniff](http://xiaix.me/python-shi-yong-scapy-jin-xing-zhua-bao/)

### Vagrant

> 自動化虛擬機的安裝和配置過程，如開機、安裝 MySQL、網路環境配置、主機與虛擬機間的文件共享等，配合 *Vagrantfile* 使用。Vagrant 視虛擬機為「Provider」、映像檔（ Image ）為「Box」

* https://gogojimmy.net/2013/05/26/vagrant-tutorial/
