# 调试 Linux 内核启动

## 准备调试环境

本次实验使用 ArchLinux 发行版进行，使用 ArchLinux 的包管理器可以很方便的完成编译调试环境的准备。并且因为 ArchLinux 的软件包比较新，可以避免很多由于版本过旧带来的问题。

### 安装必要的软件

```shell
sudo pacman -S base-devel
sudo pacman -S gcc qemu gdb
```

### 软件版本信息

```shell
➜  uname -a
Linux archlinux 4.15.14-1-ARCH #1 SMP PREEMPT Wed Mar 28 17:34:29 UTC 2018 x86_64 GNU/Linux
➜  gcc --version
gcc (GCC) 7.3.1 20180312
➜  gdb --version
GNU gdb (GDB) 8.1
➜  qemu-system-x86_64 --version
QEMU emulator version 2.11.1
➜  make --version
GNU Make 4.2.1
Built for x86_64-unknown-linux-gnu
```

## 编译 Linux 内核

方便起见，这次试验使用和我的发行版相同版本的内核

首先从 USTCLUG mirrors 下载 Linux Kernel 代码并解压

```sh
➜  wget http://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v4.x/linux-4.15.14.tar.gz
➜  tar xvf linux-4.15.14.tar.gz
```

进入源代码文件夹，配置编译选项，并开始编译

```shell
➜  cd linux-4.15.14
# 使用默认的配置来编译 Linux Kernel
➜  make defconfig
# 手动修改一项配置 .config, CONFIG_DEBUG_INFO=y
➜  make -j	
```

（如果机器的内存较小，make -j 可能会出现问题）

等待执行结束（约 5-10 分钟），的到编译好的 Linux 内核，准备启动。

## 制作 initramfs

使用 mkinitcpio 制作一个 initramfs

```shell
➜  linux-4.15.14 mkinitcpio -g ./initramfs.img -k 4.15.14-1-ARCH
==> Starting build: 4.15.14-1-ARCH
  -> Running build hook: [base]
  -> Running build hook: [udev]
  -> Running build hook: [autodetect]
  -> Running build hook: [modconf]
  -> Running build hook: [block]
  -> Running build hook: [filesystems]
  -> Running build hook: [keyboard]
  -> Running build hook: [fsck]
==> Generating module dependencies
==> Creating gzip-compressed initcpio image: /home/hejiyan/linux-4.15.14/initramfs.img
==> WARNING: Not building as root, ownership cannot be preserved
==> Image generation successful
```

这样适用于 4.15.14-1-ARCH 内核的 initramfs 就创建好了。

## 创建启动脚本

创建启动虚拟机的脚本 `start.sh.`

这里为了方便，使用我的系统自带的 `initramfs-linux.img` 作为 `initramfs`

```shell
#!/bin/sh
KERNEL="arch/x86_64/boot/bzImage"
INITRD="initramfs.img"
APPEND="nokaslr console=ttyS0"
GDB_PORT="tcp::1234"
DEBUG_FLAG="-S"

qemu-system-x86_64 \
	-nographic -serial mon:stdio \
	-append "$APPEND" \
	-initrd "$INITRD" \
	-kernel "$KERNEL" \
	-gdb "$GDB_PORT" \
	$DEBUG_FLAG
```

其中

因为我是使用 SSH 连接上服务器的，没有配置桌面环境，所以这里使用了 `-nographic -serial mon:stdio`，将虚拟机的显示输出到屏幕上，如果需要退出，需要切换到 QEMU Moniter，使用 `Ctrl+A, C`，然后输入 `quit` 退出。

最后给启动脚本加上执行权限

```shell
chmod +x start.sh
```

## 调试准备

首先使用 gdb 载入编译之后得到的 vmlinux，vmlinux 是一个没有压缩过的 kernel 镜像，可以得到所有符号，方便下面的调试

```shell
➜ gdb vmlinux
GNU gdb (GDB) 8.1
Copyright (C) 2018 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
and "show warranty" for details.
This GDB was configured as "x86_64-pc-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
<http://www.gnu.org/software/gdb/documentation/>.
For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from vmlinux...done.
```

可以看出 gdb 已经成功加载了符号表。

下一步是开一个新的终端，执行 `start.sh` 启动模拟器，启动成功后，我们会看到空白的输出，因为此时 QEMU 已经停在了模拟机器上电后的状态，方便我们调试。

现在将 gdb 连上 QEMU

```shell
(gdb) target remote localhost:1234
Remote debugging using localhost:1234
0x000000000000fff0 in cpu_hw_events ()
```

这里的 `locolhost:1234` 就是上文给 QEMU 指定的 gdb server 的地址。

## 开始调试

### 计算机上电启动

首先我们查看机器上电启动后，寄存器的情况：

```shell
(gdb) info reg
rax            0x0	0
rbx            0x0	0
rcx            0x0	0
rdx            0x663	1635
rsi            0x0	0
rdi            0x0	0
rbp            0x0	0x0 <irq_stack_union>
rsp            0x0	0x0 <irq_stack_union>
r8             0x0	0
r9             0x0	0
r10            0x0	0
r11            0x0	0
r12            0x0	0
r13            0x0	0
r14            0x0	0
r15            0x0	0
rip            0xfff0	0xfff0 <cpu_hw_events+3152>
eflags         0x2	[ ]
cs             0xf000	61440
ss             0x0	0
ds             0x0	0
es             0x0	0
fs             0x0	0
gs             0x0	0
```

比较关键的两个寄存器就是：

```shell
rip            0xfff0	0xfff0 <cpu_hw_events+3152>
cs             0xf000	61440
```

查看函数调用栈：

```shell
(gdb) info stack
#0  0x000000000000fff0 in cpu_hw_events ()
#1  0x0000000000000000 in ?? ()
```

可以看出，机器启动后，某种机制会使得连个关键寄存器为特定的值，根据规定，这两个寄存器计算出的物理地址为：0xFFFFFFF0，我们的第一条指令就储存在那个地址，那些指令可以初始化引导器或者启动操作系统。

这一些阶段，都和硬件和体系结构高度相关，属于比较底层的内容，随着启动过程，程序会越来越硬件无关，下面我选取了几个比较典型和关键的事件进行调试分析。

###  从实模式向保护模式跳转

Linux 启动过程中一个重要的步骤就是从实模式（real-mode）向保护模式（protected-mode）跳转，这个最关键的过程就是在 `go_to_protected_mode()` 这个函数中完成的

`go_to_protected_mode` 位于 `arch/x86/boot/pm.c`，下面是相关代码

```c
void go_to_protected_mode(void)
{
	/* Hook before leaving real mode, also disables interrupts */
	realmode_switch_hook();

	/* Enable the A20 gate */
	if (enable_a20()) {
		puts("A20 gate not responding, unable to boot...\n");
		die();
	}

	/* Reset coprocessor (IGNNE#) */
	reset_coprocessor();

	/* Mask all interrupts in the PIC */
	mask_all_interrupts();

	/* Actual transition to protected mode... */
	setup_idt();
	setup_gdt();
	protected_mode_jump(boot_params.hdr.code32_start,
			    (u32)&boot_params + (ds() << 4));
}
```

在 gdb 中添加一个断点再继续运行（continue）到 `go_to_protected_mode`

```shell
(gdb) b go_to_protected_mode
Function "go_to_protected_mode" not defined.
```

因为这些代码过于底层没有在 vmlinux 留下符号，所以我们只能通过在函数中插入输出调试信息的方法来跟踪了。

这一部分，在后面的自己编写 trace 工具中详细展示。

### start_kernel()

从 `start_kernel()` 开始 Linux Kernel 开始进入了与体系结构，与汇编代码相关性更低的层级。

`start_kernel()` 中完成了 Linux Kernel 的大部分初始化工作，所以我们可以试着调试运行这个过程。

打上断点：

```shell
(gdb) b start_kernel
Breakpoint 1 at 0xffffffff8275b9da: file init/main.c, line 515.
```

继续运行，会停在 `start_kernel()`：

```shell
(gdb) c
Continuing.

Breakpoint 1, start_kernel () at init/main.c:515
515	{
```

查看当前的调用栈：

```shell
(gdb) info stack
#0  start_kernel () at init/main.c:515
#1  0xffffffff810000d5 in secondary_startup_64 () at arch/x86/kernel/head_64.S:239
#2  0x0000000000000000 in ?? ()
```

查看当前的寄存器值：

```shell
(gdb) i register
rax            0x0	0
rbx            0x0	0
rcx            0x0	0
rdx            0x0	0
rsi            0x2828350d	673723661
rdi            0x14050	82000
rbp            0x0	0x0 <irq_stack_union>
rsp            0xffffffff82203f50	0xffffffff82203f50 <init_thread_union+16208>
r8             0xffffffffffff	281474976710655
r9             0xffff0000ffffffff	-281470681743361
r10            0xffffffff82203f10	-2111815920
r11            0xffffffff82203f28	-2111815896
r12            0x0	0
r13            0x0	0
r14            0x0	0
r15            0x0	0
rip            0xffffffff8275b9da	0xffffffff8275b9da <start_kernel>
eflags         0x46	[ PF ZF ]
cs             0x10	16
ss             0x0	0
ds             0x0	0
es             0x0	0
fs             0x0	0
gs             0x0	0
```

打印接下来的代码：

```shell
(gdb) l start_kernel
510		/* Should be run after espfix64 is set up. */
511		pti_init();
512	}
513
514	asmlinkage __visible void __init start_kernel(void)
515	{
516		char *command_line;
517		char *after_dashes;
518
519		set_task_stack_end_magic(&init_task);
```

使用 `next` 单步执行，直到到达 `start_kernel()` 最后的一个调用 `rest_init()`

单步进入：

```shell
(gdb) l
391	static noinline void __ref rest_init(void)
392	{
393		struct task_struct *tsk;
394		int pid;
395
396		rcu_scheduler_starting();
397		/*
398		 * We need to spawn init first so that it obtains pid 1, however
399		 * the init task will end up wanting to create kthreads, which, if
400		 * we schedule it before we create kthreadd, will OOPS.
```

此时的调用栈（刚离开 `start_kernel()`)

```shell
(gdb) i stack
#0  rest_init () at init/main.c:396
#1  0xffffffff8275bda2 in start_kernel () at init/main.c:716
#2  0xffffffff810000d5 in secondary_startup_64 () at arch/x86/kernel/head_64.S:239
#3  0x0000000000000000 in ?? ()
```

接下来，一个关键的进程启动了

```shell
(gdb) n
402		pid = kernel_thread(kernel_init, NULL, CLONE_FS);
```

随后，另一个关键进程被启动：

```shell
(gdb) n
414		pid = kernel_thread(kthreadd, NULL, CLONE_FS | CLONE_FILES);
```

目前，Linux Kernel 已经创建了三个进程，分别是

- PID=0 init
- PID=1 kernel_init
- PID=2 kthreadd

其中 init 进程没有通过 `kernel_thread` 创建，之后将作为 idle 进程。

kernel_init 在内核空间初始化，最后运行在用户态，将会成为之后系统中所有进程的祖先，可以在启动后用 pstree 看到这一现象。

kthreadd 将一直运行在内核空间，负责所有内核线程的调度和管理。

## 自己编写 trace 工具

### trace

我们希望 trace 能输出以下信息：

* 当前的运行函数和行数（方便定位）
* 当前寄存器的值
* 当前的函数调用栈


Linux Kernel 中已经有的调试工具函数：

- 打印

  ```c
  printk(const char *fmt, ...);
  ```

- 打印寄存器

    ```c
    show_regs()
    ```

- 打印调用栈

    ```c
    dump_stack()
    ```

用宏实现打印调试点的位置：

```c
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define AT __FILE__ ":" TOSTRING(__LINE__)

puts(AT);
```



```c
printk("Trace info:");
struct pt_regs regs;
prepare_frametrace(&regs);
show_regs(&regs);
dump_stack();
```

### early stage

如果需要得到上文中提到的 `go_to_protected_mode()` 的跟踪结果，则需要自己编写跟踪函数。

由于过于早期，这里 `printk()` 也不可以使用，仅有 `putchar()` 和 `puts()` 等几个函数，使用它们我们可以输出任何一个寄存器的值：

```c
// putchar 输出整数
void pr_int(int n) {
    if (n < 0) {
        putchar('-');
        n = -n;
    }
    if (n / 10 != 0)
        pr_int(n / 10);
    putchar((n % 10) + '0');
}

// 载入寄存器并输出（以 %rip 为例）
int temp;
asm("\t movl %%rip,%0" : "=r"(temp));
pr_int(temp);
```



## 附录

### 实模式（real-mode）

> **实模式**（英语：Real mode）是Intel [80286](https://zh.wikipedia.org/wiki/80286)和之后的[x86](https://zh.wikipedia.org/wiki/X86)兼容[CPU](https://zh.wikipedia.org/wiki/CPU)的操作模式。实模式的特性是一个20比特的区块内存地址空间（意思为只有1 [MB](https://zh.wikipedia.org/wiki/MB)的内存可以被定址），可以直接软件访问[BIOS](https://zh.wikipedia.org/wiki/BIOS)例程以及周边硬件，没有任何硬件档次的[内存保护](https://zh.wikipedia.org/wiki/%E8%A8%98%E6%86%B6%E9%AB%94%E4%BF%9D%E8%AD%B7)观念或[多任务](https://zh.wikipedia.org/wiki/%E5%A4%9A%E5%B7%A5)。所有的[80286](https://zh.wikipedia.org/wiki/80286)系列和之后的x86 CPU都是以实模式下开机；[80186](https://zh.wikipedia.org/wiki/80186)和早期的CPU仅仅只有一种操作模式，也就是相当于后来芯片的这种实模式。

### 保护模式（protected-mode）

>**保护模式**（英语：Protected Mode，或有时简写为 pmode）是一种[80286](https://zh.wikipedia.org/wiki/80286)系列和之后的[x86](https://zh.wikipedia.org/wiki/X86)兼容[CPU](https://zh.wikipedia.org/wiki/CPU)的运行模式。保护模式有一些新的特性，如[内存保护](https://zh.wikipedia.org/wiki/%E8%A8%98%E6%86%B6%E9%AB%94%E4%BF%9D%E8%AD%B7)，[标签页](https://zh.wikipedia.org/wiki/%E5%88%86%E9%A0%81)系统以及硬件支持的[虚拟内存](https://zh.wikipedia.org/wiki/%E8%99%9A%E6%8B%9F%E5%86%85%E5%AD%98)，能够增强[多任务处理](https://zh.wikipedia.org/wiki/%E5%A4%9A%E4%BB%BB%E5%8A%A1%E5%A4%84%E7%90%86)和系统稳定度。现今大部分的x86[操作系统](https://zh.wikipedia.org/wiki/%E4%BD%9C%E6%A5%AD%E7%B3%BB%E7%B5%B1)都在保护模式下运行，包含[Linux](https://zh.wikipedia.org/wiki/Linux)、[FreeBSD](https://zh.wikipedia.org/wiki/FreeBSD)、以及[微软](https://zh.wikipedia.org/wiki/%E5%BE%AE%E8%BB%9F)[Windows 2.0](https://zh.wikipedia.org/wiki/Windows_2.0)和之后版本。

## 参考资料

http://www.ruanyifeng.com/blog/2013/02/booting.html

https://zh.wikipedia.org/zh-cn/%E7%9C%9F%E5%AF%A6%E6%A8%A1%E5%BC%8F

https://zh.wikipedia.org/wiki/%E4%BF%9D%E8%AD%B7%E6%A8%A1%E5%BC%8F

https://kernelnewbies.org/KernelHacking-HOWTO/Debugging_Kernel

https://wiki.ubuntu.com/Kernel/KernelDebuggingTricks
