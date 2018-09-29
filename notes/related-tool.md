# 開發 P4 程式時會使用到的相關工具

## tutorials

到 [p4lang/tutorials](https://github.com/p4lang/tutorials.git) 可以找到更多範例及相關資源

## xterm

- 設定

  ```shell
  xterm -fa Monospace -fs 12
  ```

## Scapy

### Doc

[Link](http://scapy.readthedocs.io/en/latest/index.html)

### 常用函式

#### 送封包

[Stacking layers](https://scapy.readthedocs.io/en/latest/usage.html?highlight=show#stacking-layers)：使用 `/`  和 protocols 組合出任意封包；

protocols (layer) 參數放 raw data 可以轉成 Scapy 形式。

* `send(pkt)`：用來送 layer 3 封包（會幫忙處理 layer 2 和 routing)
* `sendp(pkt)`: 用來送 layer 2 封包（自己可以決定 layer 2 的一些參數） 

```python
raw(IP())
IP(_)
```

#### 看封包內容

[Ref 1](https://scapy.readthedocs.io/en/latest/usage.html?highlight=show#graphical-dumps-pdf-ps), [Ref 2](https://scapy.readthedocs.io/en/latest/usage.html?highlight=show#generating-sets-of-packets)

* `raw(pkt)` after Scapy v2.4.0 or `str(pkt)` before it
  * `raw(IP())`
* [`hexdump(pkt)`](https://scapy.readthedocs.io/en/latest/usage.html?highlight=show#hexdump)
* `ls(protocol)`：可以用來知道 protocols 的 fields 有哪些
* `pkt.summary()`
* `pkt.show()`
* `pkt.show2()`
* `pkt.decode_payload_as()`
* `pkt.hide_defaults()`
* `pkt[protocol]`
* `pkt[protocol].field`

#### 監測封包

* [sniff](https://github.com/secdev/scapy/blob/master/scapy/sendrecv.py#L794-L796)
  * [Usage](https://scapy.readthedocs.io/en/latest/usage.html?highlight=sniff#sniffing)
  * `filter` 使用 [Berkeley Packet Filter (BPF)](http://biot.com/capstats/bpf.html) 語法

## Vagrant

* 自動化虛擬機的安裝和配置過程，如開機、安裝 MySQL、網路環境配置、主機與虛擬機間的文件共享等，配合 *Vagrantfile* 使用
* Vagrant 視虛擬機為「Provider」、映像檔（ Image ）為「Box」

* 指令看 cheetsheet
