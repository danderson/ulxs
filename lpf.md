# LPF file format specification

LPF (Lattice Preference File) files are how you express routing
constraints and I/O pin configuration for Lattice ECP5
FPGAs. Annoyingly, it seems Lattice doesn't document the format, and
instead forces you to use their proprietary design software to
generate LPF files.

Separately, projects like the ULX3s board provide a pre-baked LPF file
that documents most of the "hardcoded" routing of board features to
FPGA pins, but requires tweaking for some applications (e.g. to add
pull-ups, pull-downs, change the drive current...).

I tried getting a license for Lattice Diamond on their website, but
they won't let me get a free license to use their
software without "account approval", which takes "up to 2 business
days". It's Saturday, so instead of waiting for that I'm going to
write down a google-able specification of LPF files, as parsed by
nextpnr, so that people don't have to go through that themselves.

## General format

LPF files are plain text files, with one directive per
line. Directives are terminated by a semicolon.

Line comments are supported, from the `#` character to the end of the
line.

Each line consists of words. The first word or two define the type of
line, and the rest of the line consists of required positional
arguments and optional keyword arguments.

A small excerpt of a valid LPF file:

```
SYSCONFIG CONFIG_IOVOLTAGE=3.3 COMPRESS_CONFIG=ON MCCLK_FREQ=62 MASTER_SPI_PORT=ENABLE SLAVE_SPI_PORT=DISABLE SLAVE_PARALLEL_PORT=DISABLE;
# The FTDI chip provides a serial line to USB port US1.
LOCATE COMP "ftdi_rxd" SITE "L4"; # FPGA transmits to ftdi
IOBUF PORT "ftdi_rxd" PULLMODE=UP IO_TYPE=LVCMOS33 DRIVE=4;
```

## Signal names

Several directives accept signal names to reference wires in your
design. The signal names correspond to the ports in your design's
top-level module. Signal names are case sensitive, so must exactly
match the definitions in your HDL.

If your top-level ports contain arrays, your LPF file must manage each
array bit individually. Array bits are referenced using the syntax
`array_name[idx]`.

When handling signals, remember that by the time the LPF file is being
read, synthesis has already been done. So, if you declared a
single-ended output signal, it makes no sense to tie it to a pin
configured as a differential input. Your synthesis tool will still
happily produce a bitstream describing this, but your design is not
going to work correctly.

As an example, if your top-level Verilog module is:

```
module top(input clk, input [2:0] test_btn, output [1:0] statusLeds);
  ...
endmodule
```

Then your LPF file needs to define configuration for signals named
`clk`, `test_btn[0]`, `test_btn[1]`, `test_btn[2]`, `statusLeds[0]`,
and `statusLeds[1]`.

## SYSCONFIG directive

The SYSCONFIG directive sets global FPGA options relating to bitstream
generation and loading. When the FPGA first powers on, it has no
bitstream loaded, and must get it from external storage. SYSCONFIG
specifies basic hardware settings to facilitate that loading.

The ECP5 can read its configuration bitstream from several sources,
dictated by hardcoded signal levels on the `CFGMDN` pins of the
`sysCONFIG` I/O block. See application node TN1260 from Lattice for
details. Briefly, the `CFGMDN` pins put the ECP5 into one of 4 modes:
 - SPI master: the ECP5 reads configuration out of a flash chip
   attached to the SPI pins of the `sysCONFIG` block. It starts out
   reading at 2.4MHz, but once it's read enough of the bitstream to
   find the `MCCLK_FREQ` option (see below), it can increase its clock
   speed for the majority of the read-out.
 - SPI slave: the ECP5 listens on the SPI pins of the `sysCONFIG`
   block and waits for an external SPI master to send it a bitstream.
 - Serial slave: same, but through a serial interface.
 - Parallel slave: same, but through a parallel interface.

Depending on the configuration settings below, the ports may remain
active after the bitstream has loaded (which allows things like having
a CPU access and reconfigure a running device), or the pins can revert
to I/O pins usable by your gateware.

Keeping the ports enabled after initial configuration is mostly useful
if you want to access them through JTAG later (e.g. to flash a new
config to non-volatile storage through the FPGA's JTAG port)

Programming and debugging is always available through the JTAG port,
regardless of the `sysCONFIG` mode.

SYSCONFIG takes only optional keyword arguments, which are:
 - `CONFIG_IOVOLTAGE`: sets the pin voltage used on pins in the
   `sysCONFIG` group. One of `1.2`, `1.5`, `1.8`, `2.5` (the default),
   `3.3`.
 - `COMPRESS_CONFIG`: whether the bitstream generator should use
   compression. One of `OFF` (the default) or `ON` (recommended by
   Lattice).
 - `MCCLK_FREQ`: in SPI master mode, the frequency in MHz at which to
   read configuration from the SPI interface. One of `2.4` (the
   default), `4.8`, `9.7`, `19.4`, `38.8`, `62`.
 - `MASTER_SPI_PORT`: whether the built-in SPI master remains active
   and blocking the SPI pins after initial loading has completed. One
   of `ENABLE` or `DISABLE` (the default). Cannot be set to `ENABLE`
   at the same time as `SLAVE_SPI_PORT`.
 - `SLAVE_SPI_PORT`: whether the built-in SPI slave remains active and
   blocking the SPI pins after initial loading has completed. One of
   `ENABLE` or `DISABLE` (the default). Cannot be set to `ENABLE` at
   the same time as `MASTER_SPI_PORT`.
 - `SLAVE_PARALLEL_PORT`: whether the built-in slave parallel port
   remains active and blocking the parallel port pins after initial
   loading has completed. One of `ENABLE` or `DISABLE` (the default).
 - `BACKGROUND_RECONFIG`: whether to enable soft error correction, a
   mechanism that lets you hot-reload the bitstream to correct cosmic
   ray bit flips. Requires further work on your part to actually use,
   see TN1184 for details.
 - `DONE_PULL`: whether the `DONE` pin should be configured with an
   internal pull-up resistor. One of `ON` (the default) or `OFF`.
 - `DONE_EX`: whether to delay the end of configuration based on the
   input value of `DONE`. Used when daisy-chaining FPGAs, combined
   with the `DONE_OD` and `DONE_PULL` options so that all FPGAs have
   to release `DONE` before any of them can start running. See TN1260
   appendix D for more. One of `ON` or `OFF` (the default).
 - `DONE_OD`: whether to configure the `DONE` pin as an open drain,
   rather than a fully driven output. One of `ON` or `OFF` (the
   default).
 - `CONFIG_SECURE`: whether to allow external read-back of the
   configuration through JTAG and other programming ports. If enabled,
   the FPGA must be wiped before it can be reprogrammed. One of `ON`
   or `OFF` (the default).
 - `CONFIG_MODE`: which bus and mode is being used to load
   configuration. This option doesn't alter the bitstream at all, it's
   only here so that the Lattice IDE can block off the right sets of
   pins from user use based on the selected config mode. One of `JTAG`
   (the default), `SSPI`, `SPI_SERIAL`, `SPI_DUAL`, `SPI_QUAD`,
   `SLAVE_PARALLEL`, `SLAVE_SERIAL`.
 - `TRANSFR`: whether the bitstream is intended for loading using
   Lattice's "TransFR" tools, which allow for field reconfiguration
   with minimal disruption. Exact effect unknown. One of `ON` or `OFF`
   (the default).
 - `WAKE_UP`: controls the ordering of setting `DONE=1` relative to
   other actions during the transition from configuration mode (aka
   FPGA being programmed) to user mode (aka running FPGA). One of `4`
   (set `DONE=1` before starting user code) or `21` (set `DONE=1` once
   the FPGA has already started running user code). The default is `4`
   when `DONE_EX=ON` and `21` when `DONE_EX=OFF`.
 - `INBUF`: whether to disable unused input buffers to save power. One
   of `ON` or `OFF`. [Ed. may not exist in ECP5, only referenced in
   ECP2 sysCONFIG. But nextpnr parses it, so I'm including it here for
   completeness.]

Example SYSCONFIG line:

```
SYSCONFIG CONFIG_IOVOLTAGE=3.3 COMPRESS_CONFIG=ON MCCLK_FREQ=62;
```

## LOCATE COMP directive

The `LOCATE COMP` directive assigns top-level signal in your design to
a physical pin of the FPGA. It is commonly paired with an `IOBUF PORT`
directive to fully specify the behavior of the pin.

The syntax is:

```
LOCATE COMP "signal_name" SITE "pin_name";
```

`signal_name` is the name of a top-level signal in your HDL. See the
"Signal names" section above for detailed syntax and behavior.

The `pin_name` is the name of the pin from the datasheet, e.g. `H3` or
`R18`.

Example `LOCATE COMP` line, attaching the LSB of the `btn` array to
pin D6:

```
LOCATE COMP "btn[0]" SITE "D6";
```

## FREQUENCY PORT directive

The `FREQUENCY PORT` directive adds a timing constraint to a top-level
signal in your design. Typically, you would use this to tell the
place-and-route tool about incoming clock signals, so that timing
analysis can verify that the design is stable at that frequency.

[Ed. TODO: can you define frequency constraints for internal signals
as well? For example, if you use a PLL module to generate a 300MHz
internal clock, can you tag that wire with a frequency constraint?]

The syntax is:

```
FREQUENCY PORT "signal_name" number unit;
```

`signal_name` is the name of a top-level signal in your HDL. See the
"Signal names" section above for detailed syntax and behavior.

Valid `unit`s are `MHZ`, `KHZ` and `HZ`.

Example:

```
FREQUENCY PORT "clk" 25 MHZ;
```

## IOBUF PORT directive

The `IOBUF PORT` directive configures the physical I/O pin properties
of a top-level signal in your design. It is commonly paired with a
`LOCATE COMP` line to attach an HDL wire to the pin.

The syntax is:

```
IOBUF PORT "signal_name" KEY=VALUE...;
```

`signal_name` is the name of a top-level signal in your HDL. See the
"Signal names" section above for detailed syntax and behavior.

The following key/value pairs exist:
 - `IO_TYPE`: specifies the electrical I/O standard the pin will
   obey. Valid values are constrained by the I/O reference voltage
   provided to the relevant I/O bank, as detailed in TN1262. All valid
   values are:
     - Basic single pin standards: `LVTTL33`, `LVCMOS33`, `LVCMOS25`,
       `LVCMOS18`, `LVCMOS15`, `LVCMOS12`.
	 - Advanced single pin standards (mostly for driving different
       DRAM chips): `HSUL12`, `SSTL15_I`, `SSTL15_II`, `SSTL135_I`,
       `SSTL135_II`, `SSTL18_I`, `SSTL18_II`.
	 - Differential standards (must be paired with another signal,
       consult TN1262 for valid pin pairings): `LVDS`, `LVDS25E`,
       `BLVDS25`, `LVPECL33`, `LVPECL33E`, `MLVDS`, `MLVDS25E`,
       `SLVS`, `SUBLVDS`, `HSUL12D`, `SSTL15D_I`, `SSTL15D_II`,
       `SSTL135D_I`, `SSTL135D_II`, `SSTL18D_I`, `SSTL18D_II`,
       `LVTTL33D`, `LVCMOS33D`, `LVCMOS25D`, `LVCMOS18D`.
 - `OPENDRAIN`: whether this pin should be configured as an open
   drain. One of `ON` or `OFF` (the default).
 - `DRIVE`: the amount of current (in mA) to drive when
   outputting. Valid values depend on the I/O type, see table 8 of
   TN1262. For example, valid values for LVTTL33 are `4`, `8`, `12`,
   and `16`.
 - `DIFFDRIVE`: the amount of drive current for pins using LVDS
   mode. The only allowed value is 3.5mA, its encoding is unknown.
 - `TERMINATION`: the input parallel termination to configure, if
   any. One of `OFF` (the default), `50`, `75`, or `100` ohms.
 - `DIFFRESISTOR`: the differential termination to configure, if
   any. One of `OFF` (the default) or `100` (ohms).
 - `CLAMP`: for top and bottom banks, whether to enable input clamping
   to VCCIO. One of `OFF` (the default) or `ON`. Input clamping is
   hardwired on for left and right banks.
 - `BANK`: [Ed. unknown, not documented in Lattice TN or seen in the wild]
 - `BANK_VCC`: [Ed. unknown, not documented in Lattice TN or seen in the wild]
 - `VREF`: must be set to `VREF1_LOAD` for `HSUL` and `SSTL` pin
   types. `OFF` and ignored for other types.
 - `PULLMODE`: whether to attach a pull-up or pull-down resistor to
   the pin. One of `NONE`, `UP`, or `DOWN` (the default).
 - `HYSTERESIS`: whether to enable input hysteresis. Only applicable
   to `LVTTL33`, `LVCMOS33` and `LVCMOS25` pins. One of `ON` (the
   default for those types) or `OFF`.
 - `SLEWRATE`: the desired slew rate for output on the pin. Only
   applicable to `LVTTL` and `LVCMOS` pin types. One of `FAST` or
   `SLOW`.
