// SPDX-License-Identifier: GPL-2.0-only
/*
 * Xiaomi Display Features Driver (HBM, DC Dimming)
 * Copyright (C) 2024-2026 Custom Kernel Team
 */

#include <linux/module.h>
#include <linux/init.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>
#include <linux/string.h>

static int hbm_mode;
static int dc_dim_mode;

static ssize_t hbm_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", hbm_mode);
}

static ssize_t hbm_store(struct kobject *kobj, struct kobj_attribute *attr,
			 const char *buf, size_t count)
{
	int val;
	if (kstrtoint(buf, 10, &val))
		return -EINVAL;

	hbm_mode = !!val;
	pr_info("disp_features: HBM set to %d\n", hbm_mode);
	return count;
}

static ssize_t dc_dim_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	return scnprintf(buf, PAGE_SIZE, "%d\n", dc_dim_mode);
}

static ssize_t dc_dim_store(struct kobject *kobj, struct kobj_attribute *attr,
			    const char *buf, size_t count)
{
	int val;
	if (kstrtoint(buf, 10, &val))
		return -EINVAL;

	dc_dim_mode = !!val;
	pr_info("disp_features: DC Dimming set to %d\n", dc_dim_mode);
	return count;
}

static struct kobj_attribute hbm_attr = __ATTR(hbm, 0664, hbm_show, hbm_store);
static struct kobj_attribute dc_dim_attr = __ATTR(dc_dim, 0664, dc_dim_show, dc_dim_store);
static struct kobj_attribute dc_dimming_attr = __ATTR(dc_dimming, 0664, dc_dim_show, dc_dim_store);

static struct attribute *disp_features_attrs[] = {
	&hbm_attr.attr,
	&dc_dim_attr.attr,
	&dc_dimming_attr.attr,
	NULL,
};

static struct attribute_group disp_features_group = {
	.attrs = disp_features_attrs,
};

static struct kobject *disp_kobj;

static int __init disp_features_init(void)
{
	int ret;

	disp_kobj = kobject_create_and_add("display_features", kernel_kobj);
	if (!disp_kobj)
		return -ENOMEM;

	ret = sysfs_create_group(disp_kobj, &disp_features_group);
	if (ret) {
		kobject_put(disp_kobj);
		return ret;
	}

	pr_info("Xiaomi Display Features (HBM & DC Dimming) initialized\n");
	return 0;
}

static void __exit disp_features_exit(void)
{
	if (disp_kobj) {
		sysfs_remove_group(disp_kobj, &disp_features_group);
		kobject_put(disp_kobj);
	}
}

module_init(disp_features_init);
module_exit(disp_features_exit);

MODULE_DESCRIPTION("Xiaomi Display Features (HBM & DC Dimming)");
MODULE_LICENSE("GPL v2");
