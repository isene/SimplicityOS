# XRPN Coverage

Status of all 274 XRPN commands on Simplicity OS.
154 implemented, 119 skipped for a named reason, 1 excluded (getweb).

Two entry points share the same words:

- Calculator: `xrpn`, type FOCAL lines interactively.
- Programs: `tools/xrpn2forth` translates `.xrpn` files to apps.

## Implemented (154)

- Stack: enter, lift, swap/xy/x<>y, rup/r^, rdn, clx, clst, clear,
  lastx, drop, dropy, RIGHT/LEFT (xy), UP (rup), DOWN (drop)
- Arithmetic: + - * / (and add/subtract/multiply/divide), pow, chs,
  abs, sqrt, sqr/x^2, cube, 1/x, recip, mod, fact, %, %ch, sign,
  int, frc, rnd, pi, rand
- Transcendental: sin, cos, tan, asin, acos, atan, ln, log, exp,
  tenx, expx1, ln1x, root, deg, rad, grad, d_r, r_d, p_r, r_p
- Registers: sto, rcl, st+, st-, st*, st/, sto ind, rcl ind,
  x<> y/z/t/l/NN, clrg, size, size?
- Flags: sf, cf, fs?, fc?, fs?c, fc?c, invf, x<>f, stoflag, rclflag
- Conditionals: x=0? x!=0? x<0? x>0? x<=0? x>=0? and the same six
  against Y and against nn (all 18, plus x# aliases)
- Loops: dse, isg
- Alpha: "text", |-text append, asto, arcl, arcl x, arcli, aleng,
  arot, ashf, atox, xtoa, anum, posa, cla, aview, aviewc, prompt
- Statistics: splus, sminus, mean, sdev, cls, sreg, correct
- Base: dechex, hexdec, decbin, bindec, decoct, octdec
- Time and sound: time, date, dow, hr, hms, hms+, hms-, beep, tone,
  tonexy, pse, getkey, getkeyx
- Display: prx, prstack, prregs, prflags, pra, adv, cld, fix
- Program flow (translator): lbl, gto, xeq, gsb, rtn, stop, end
- Misc: geir, version, sizeq, off/end (leaves xrpn, not the OS)

## Skipped (119), by reason

- Host OS integration (24): rubycmd, shellcmd, ed, cat, copy, move,
  load, help, open, writefile, saveas, savep, saver, saverx, savex,
  stdout, error, unerror, cmdadd, cmddel, cmds, cmdhelp, agsub, asub.
  These need Ruby, a shell or a host file tree.
- HP-41 file and extended memory system (39): crfld, crflas, clfl,
  flsize, purfl, reszfl, posfl, getas, getfile, getfilea, getrec,
  getrx, getsub, getx, getp, getr, appchr, apprec, arclrec, asroom,
  delchr, delrec, inschr, insrec, seekpt, seekpta, rclpt, rclpta,
  swpt, savexm, pack, psize, emdir, emdirx, emroom, xmexistq,
  xmfileq, setaf, rclaf. Simplicity has no file system yet.
- Alarm catalog (6): almcat, almnow, clalma, clalmx, clralms,
  xyzalm. The native `uac` app covers alarms.
- Date and clock formatting (12): adate, adateiso, atime, atime24,
  ddate, dateplus, dmy, mdy, clk12, clk24, dot, sep. Formatting of X
  into alpha; use `arcl x`.
- Stopwatch (6): sw, setsw, runsw, stopsw, rclsw, clock.
- Key assignments (5): pasn, clkeys, aon, aoff, on. No user-definable
  keyboard yet.
- Display modes (7): sci, eng, oct, dec, fixq, degq, sregq. FIX is
  the one display mode.
- Program listing and printer (14): page, pageq, pagedel, pageswap,
  lastpage, clp, pclps, pprg, pprgx, pprgtofile, prp, prxm, pcat, tx.
  Programs live as Forth words, not numbered pages.
- Register block operations (3): regmove, regswap, clrgx.
- RAW files (3): rawimport, rawexport, rawinfo.

## Excluded by request (1)

- getweb. No network stack.

## Known limits

- `gto`/`xeq ind` and computed jumps have no translation; labels
  become words at translate time.
- `rtn`/`stop` only at the end of a label block; one gto-self loop
  per block.
- Interactive conditionals print YES or NO instead of skipping the
  next line.
