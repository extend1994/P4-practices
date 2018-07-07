# P4 運行環境

## P4 Modular Compiler

![modular.png](https://i.imgur.com/8R4z3Dl.png)

Single Front-End (p4-hlir) + Multiple backends.
Backends involve

- Code generators for various targets, e.g. Software Switch Model (p4c-bm)
- Validators and graph generators
- Run-time API generators

### [p4-hlir](https://github.com/p4lang/p4-hlir)

- 前端編譯器
- 將 P4 程式碼轉為 **High-Level Intermediate Representation** (HLIR)，  
  類似 Abstract Syntax Trees (AST) 的概念
- 目前以經階層式的 Python objects 呈現，只支援 P4_14
- 使得後端開發者不再因為 syntax analysis 和 target-independent semantic checking 感到困擾

## [behavioral-model](https://github.com/p4lang/behavioral-model)

- behavioral-model version 2 是最新版本，因此常被稱為 bmv2
- [Documentation](http://104.236.137.35/)
- 一個 P4 軟體 switch，作為 P4 target
- 由 C++ 寫出來的 user-space software switch，模擬 P4 dataplane
- 含有一些讓開發變得容易的工具
  - runtime CLI to program
  - a GDB-like debugger

### Workflow

![workflow](https://upload.cc/i1/2018/05/27/PWDlHN.png)

- p4c-bm 將 P4 program 編譯成 json 格式的配置文件，並將之載入到 bmv2，轉化成能實現 switch 功能的數據結構

### [p4c-bm](https://github.com/p4lang/p4c-bm)

- 運用在 bmv2，常被稱為 p4c-bmv2
- The reference P4 compiler for behavioral model
- 以 P4 program 為輸入，產生要載入到 behavioral model 的 JSON 檔案

### Targets（要載入 P4 program 的對象）

- [simple_router](https://github.com/p4lang/behavioral-model/tree/master/targets/simple_router)
  - 最小、最簡單的 target，上手容易
- [l2_switch](https://github.com/p4lang/behavioral-model/tree/master/targets/l2_switch)
  - 相較於 simple router，引入了 *packet replication engine*，可支援 multicast
- [simple_switch](https://github.com/p4lang/behavioral-model/tree/master/targets/simple_switch)
  - 相較前面兩個 targets，支援最多功能
  - 但程式碼還是相對小、容易理解

### thrift-port

網路中 switch 的接口。  
runtime 階段可以使用這個接口來命令不同的 switch 做不同的事情。
***bmv2 中預設為 9090***

### 延伸工具

* 驗證 P4_14 語法

  ```p4
  p4-validate <path_to_p4_program>
  ```

* 存取 HLIR instances  

  ```shell
  # Method 1 - Use built HLIR
  p4-shell <path_to_p4_program>
  ```

  ```python
  # Method 2 - Manually build HLIR
  from p4_hlir.main import HLIR
  h = HLIR(<path_to_p4_program>)
  h.build()
  ```

  之後便可以在 Python 的 interactive shell 中存取以下 instances

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

## 如何運行 P4 程式

- 用 `p4c-bmv2` 產生要輸入到 bmv2 的 `.json` 給  `bmv2`  ，用以配置 switch

  ```shell
  p4c-bmv2 <path_to_source_P4_file> --json <path_to_output_JSON>
  ```

- 啟動 switch

  ```shell
  $SWITCH_PATH [-i 0@<iface0> -i 1@<iface1> ...] [--nanolog] [--debugger] [--no-p4] <JSON_for_switch>
  ```

  - iface* 是綁定 switch port 的虛擬網卡介面
  - 若要使用 debugger，需要先 enable
  - `--no-p4` 的選項就是不使用 P4 語言配置 switch，單純啟動

- 設定網路拓樸，並將 P4 配置的 JSON 檔案載入到拓樸中的 switch

  ```shell
  # 一個簡單的拓樸
  sudo python bmv2/mininet/1sw_demo.py --behavioral-exe $SWITCH_PATH --json <JSON_for_switch>
  ```

  - 其他參考拓樸

    - [overlay](https://github.com/TakeshiTseng/2016-nctu-p4-workshop/blob/master/overlay/topology.py)

      ```
      h1 0 - 0 s1 2 - 0 s2 2 - 0 h2
               1         1
               |         |
               1         1
      h3 0 - 0 s3 2 - 0 s4 2 - 0 h4
      ```

    - [1Switch, 2Hosts](https://github.com/TakeshiTseng/2016-nctu-p4-workshop/blob/master/stateful-example/topology.py)

    - [3 switches, 3 Hosts](https://github.com/p4lang/tutorials/blob/master/SIGCOMM_2015/source_routing/topo.py)
      ![](https://raw.githubusercontent.com/p4lang/tutorials/bmv2-samples/SIGCOMM_2015/resources/images/source_routing_topology.png)

- 指定 thrift port 來開啟對應 switch 的 **Runtime CLI**  

  ```shell
  # 互動模式
  $CLI_PATH [--json <JSON_for_switch>] [--thrift-port <port>]
  # 載入寫有 table entries 指令的文字檔案到 switch
  $CLI_PATH [--json <JSON_for_switch>] [--thrift-port <port>] < commands.txt
  # 也可以單一 echo 
  echo "<action>" | $CLI_PATH [--json <JSON_for_switch>]
  ```

- 使用 Runtime CLI 下 table entry (match rules)  

  ```shell
  # Just examples
  table_set_default <table> <action> <action_para>
  table_add <table> <action> <fields> => <action_para> [priority]
  table_delete <table> <entry>
  ```

  打開 CLI 互動模式後可以按 TAB 鍵來看到所有可以進行的操作

- 使用 debugger - [tools/p4dbg.py](https://github.com/p4lang/behavioral-model/blob/master/tools/p4dbg.py)

  ```shell
  sudo ./p4dbg.py [--thrift-port <port>]
  ```





