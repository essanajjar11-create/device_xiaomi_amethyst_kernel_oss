// SPDX-License-Identifier: GPL-2.0-only
/*
 * Xiaomi Hardware ID Driver
 * Copyright (C) 2021-2024 Xiaomi, Inc.
 */

#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/device.h>
#include <linux/sysfs.h>
#include <linux/of.h>
#include "hwid.h"

static int hwid_value = 0;
static int hwid_project = 0;
static int hwid_build_adc = 0;
static int hwid_project_adc = 0;

int get_hwid_value(void)
{
	return hwid_value;
}
EXPORT_SYMBOL_GPL(get_hwid_value);

int get_hwid_project(void)
{
	return hwid_project;
}
EXPORT_SYMBOL_GPL(get_hwid_project);

static ssize_t hwid_value_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", hwid_value);
}
static DEVICE_ATTR_RO(hwid_value);

static ssize_t hwid_project_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", hwid_project);
}
static DEVICE_ATTR_RO(hwid_project);

static ssize_t hwid_build_adc_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", hwid_build_adc);
}
static DEVICE_ATTR_RO(hwid_build_adc);

static ssize_t hwid_project_adc_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", hwid_project_adc);
}
static DEVICE_ATTR_RO(hwid_project_adc);

static struct attribute *hwid_attrs[] = {
	&dev_attr_hwid_value.attr,
	&dev_attr_hwid_project.attr,
	&dev_attr_hwid_build_adc.attr,
	&dev_attr_hwid_project_adc.attr,
	NULL,
};
ATTRIBUTE_GROUPS(hwid);

static int hwid_probe(struct platform_device *pdev)
{
	struct device_node *np = pdev->dev.of_node;

	if (np) {
		of_property_read_u32(np, "hwid-value", &hwid_value);
		of_property_read_u32(np, "hwid-project", &hwid_project);
		of_property_read_u32(np, "hwid-build-adc", &hwid_build_adc);
		of_property_read_u32(np, "hwid-project-adc", &hwid_project_adc);
	}

	dev_info(&pdev->dev, "Xiaomi HWID initialized (value=%d, project=%d)\n",
		 hwid_value, hwid_project);
	return 0;
}

static int hwid_remove(struct platform_device *pdev)
{
	return 0;
}

static const struct of_device_id hwid_of_match[] = {
	{ .compatible = "xiaomi,hwid" },
	{ }
};
MODULE_DEVICE_TABLE(of, hwid_of_match);

static struct platform_driver hwid_driver = {
	.driver = {
		.name = "hwid",
		.groups = hwid_groups,
		.of_match_table = of_match_ptr(hwid_of_match),
	},
	.probe = hwid_probe,
	.remove = hwid_remove,
};

module_platform_driver(hwid_driver);

MODULE_DESCRIPTION("Xiaomi Hardware ID Driver");
MODULE_LICENSE("GPL v2");
