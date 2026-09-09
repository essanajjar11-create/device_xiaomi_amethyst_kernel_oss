/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2021-2024 Xiaomi, Inc.
 */

#ifndef _HWID_H_
#define _HWID_H_

#include <linux/types.h>

enum {
	CountryCN = 0,
	CountryGlobal = 1,
	CountryIndia = 2,
};

#define HARDWARE_PROJECT_N18	0x18
#define HARDWARE_PROJECT_O81	0x81
#define HARDWARE_PROJECT_O82	0x82

int get_hwid_value(void);
int get_hwid_project(void);
int get_hw_version_platform(void);
int get_hw_version_build(void);
int get_hw_version_minor(void);
int get_hw_version_major(void);
int get_hw_country_version(void);

#endif /* _HWID_H_ */
