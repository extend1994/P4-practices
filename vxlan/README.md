# VXLAN experiment using P4
## Introduction to this experiment
Will add it ASAP

## Environment requirement
Operating System with **bash shell**

## Instruction to demonstrate this experiment
Open you terminal and type
```shell
. run.sh vxlan
```

You will see [mininet](http://mininet.org/) then type
``` shell
xterm h1 h2
```
to wake host1 & host2

Last, in host2 window (should be done before host1)
```shell
./receiver.py
```

In host1 window
```shell
./send.py
```

You will see the last digit of raw data of sent message changed which is caused by P4.
