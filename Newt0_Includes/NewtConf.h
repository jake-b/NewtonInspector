/* src/newt_core/incs/NewtConf.h.  Generated from NewtConf.h.in by configure.  */
/*------------------------------------------------------------------------*/
/**
 * @file	NewtConf.h
 * @brief   コンフィグ情報
 *
 * @author  M.Nukui
 * @date	2003-11-07
 *
 * Copyright (C) 2003-2004 M.Nukui All rights reserved.
 */


#ifndef	NEWTCONF_H
#define	NEWTCONF_H

/* マクロ */

/// 名前付マジックポインタを使用
#define __NAMED_MAGIC_POINTER__ 1

/* VM */

/// 一度に確保するスタック長
#define NEWT_NUM_STACK			512
/// 一度に確保する呼出しスタック長
#define NEWT_NUM_CALLSTACK		512
/// 一度に確保する例外スタック長
#define NEWT_NUM_EXCPSTACK		512

/* Parser */
/// 一度に確保する構文木スタック長
#define NEWT_NUM_STREESTACK		1024

/* Bytecode */
/// 一度に確保する Bytecode のメモリ長
#define NEWT_NUM_BYTECODE		512
/// 一度に確保する break 文の作業用スタック長
#define NEWT_NUM_BREAKSTACK		20
/// 一度に確保する OnException 文の作業用スタック長
#define NEWT_NUM_ONEXCPSTACK	20

/* Pool */
///　　メモリプールの拡張サイズ
#define NEWT_POOL_EXPANDSPACE	(1024 * 10)

/* IO */
/// fgets のバッファサイズ
#define	NEWT_FGETS_BUFFSIZE		2048
/// snprintf, vsnprintf のバッファサイズ
#define NEWT_SNPRINTF_BUFFSIZE	255

/* lex */
/// 字句解析の行バッファサイズ
#define	NEWT_LEX_LINEBUFFSIZE	500

/* text encoding */
/// デフォルトエンコーディング
#define NEWT_DEFAULT_ENCODING	"UTF-8"

// for old style compatible
//#define __USE_OBSOLETE_STYLE__


#endif /* NEWTCONF_H */
