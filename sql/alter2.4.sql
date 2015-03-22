INSERT INTO `0_sys_prefs` VALUES('tax_algorithm','glsetup.customer', 'tinyint', 1, '1');
INSERT INTO `0_sys_prefs` VALUES('gl_closing_date','setup.closing_date', 'date', 8, '');
ALTER TABLE `0_audit_trail` CHANGE `fiscal_year` `fiscal_year` int(11) NOT NULL default 0;

# Fix eventual invalid date/year in audit records
UPDATE `0_audit_trail` audit 
		LEFT JOIN `0_gl_trans` gl ON  gl.`type`=audit.`type` AND gl.type_no=audit.trans_no
		LEFT JOIN `0_fiscal_year` year ON year.begin<=gl.tran_date AND year.end>=gl.tran_date
		SET audit.gl_date=gl.tran_date, audit.fiscal_year=year.id
		WHERE NOT ISNULL(gl.`type`);

DROP TABLE IF EXISTS `0_wo_costing`;

CREATE TABLE `0_wo_costing` (
  `id` int(11) NOT NULL auto_increment,
  `workorder_id` int(11) NOT NULL default '0',
  `cost_type` 	tinyint(1) NOT NULL default '0',
  `trans_type` int(11) NOT NULL default '0',
  `trans_no` int(11) NOT NULL default '0',
  `factor` double NOT NULL default '1',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB;

UPDATE `0_gl_trans` gl
		LEFT JOIN `0_cust_branch` br ON br.receivables_account=gl.account AND br.debtor_no=gl.person_id AND gl.person_type_id=2
		LEFT JOIN `0_suppliers` sup ON sup.payable_account=gl.account AND sup.supplier_id=gl.person_id AND gl.person_type_id=3
 SET `person_id` = IF(br.receivables_account, br.debtor_no, IF(sup.payable_account, sup.supplier_id, NULL)), 
 	`person_type_id` = IF(br.receivables_account, 2, IF(sup.payable_account, 3, NULL));

ALTER TABLE `0_tax_group_items` ADD COLUMN `tax_shipping` tinyint(1) NOT NULL default '0' AFTER `rate`;
UPDATE `0_tax_group_items` tgi
	SET tgi.tax_shipping=1
	WHERE tgi.rate=(SELECT 0_tax_types.rate FROM 0_tax_types, 0_tax_groups 
		WHERE tax_shipping=1 AND tgi.tax_group_id=0_tax_groups.id AND tgi.tax_type_id=0_tax_types.id);
ALTER TABLE `0_tax_groups` DROP COLUMN `tax_shipping`;

ALTER TABLE `0_sales_order_details` ADD KEY `stkcode` (`stk_code`);
ALTER TABLE `0_purch_order_details` ADD KEY `itemcode` (`item_code`);
ALTER TABLE `0_sys_prefs` CHANGE `value` `value` TEXT NOT NULL;
ALTER TABLE `0_cust_branch` ADD COLUMN `bank_account` varchar(60) DEFAULT NULL AFTER `notes`;

ALTER TABLE `0_debtor_trans` ADD COLUMN `tax_included` tinyint(1) unsigned NOT NULL default '0' AFTER `payment_terms`;
UPDATE `0_debtor_trans` tr, `0_trans_tax_details` td SET tr.tax_included=td.included_in_price
	WHERE tr.`type`=td.trans_type AND tr.trans_no=td.trans_no AND td.included_in_price;

ALTER TABLE `0_bank_accounts` ADD COLUMN `bank_charge_act` varchar(15) NOT NULL DEFAULT '' AFTER `id`;
UPDATE `0_bank_accounts` SET `bank_charge_act`=(SELECT `value` FROM 0_sys_prefs WHERE name='bank_charge_act');

ALTER TABLE `0_users` ADD `transaction_days` INT( 6 ) NOT NULL default '30' COMMENT 'Transaction days' AFTER `startup_tab`;

ALTER TABLE `0_purch_orders` ADD COLUMN `prep_amount` double NOT NULL DEFAULT 0 AFTER `total`;
ALTER TABLE `0_purch_orders` ADD COLUMN `alloc` double NOT NULL DEFAULT 0 AFTER `prep_amount`;

ALTER TABLE `0_sales_orders` ADD COLUMN `prep_amount` double NOT NULL DEFAULT 0 AFTER `total`;
ALTER TABLE `0_sales_orders` ADD COLUMN `alloc` double NOT NULL DEFAULT 0 AFTER `prep_amount`;

ALTER TABLE `0_cust_allocations` ADD  UNIQUE KEY(`trans_type_from`,`trans_no_from`,`trans_type_to`,`trans_no_to`);
ALTER TABLE `0_supp_allocations` ADD  UNIQUE KEY(`trans_type_from`,`trans_no_from`,`trans_type_to`,`trans_no_to`);

ALTER TABLE `0_sales_order_details` ADD COLUMN `invoiced` double NOT NULL DEFAULT 0 AFTER `quantity`;

# update sales_order_details.invoiced with sum of invoiced quantities on all related SI
UPDATE `0_sales_order_details` so
	LEFT JOIN `0_debtor_trans_details` delivery ON delivery.`debtor_trans_type`=13 AND src_id=so.id
	LEFT JOIN (SELECT src_id, sum(quantity) as qty FROM `0_debtor_trans_details` WHERE `debtor_trans_type`=10 GROUP BY src_id) inv
		ON inv.src_id=delivery.id
	SET `invoiced` = `invoiced`+inv.qty;

ALTER TABLE `0_debtor_trans` ADD COLUMN `prep_amount` double NOT NULL DEFAULT 0 AFTER `alloc`;

INSERT INTO `0_sys_prefs` VALUES ('deferred_income_act', 'glsetup.sales', 'varchar', '15', '');

# set others transactions edition for all roles for backward  compatibility
UPDATE `0_security_roles` SET `sections`=CONCAT_WS(';', `sections`, '768'), `areas`='775'
	WHERE NOT `sections` REGEXP '[^0-9]?768[^0-9]?';

UPDATE `0_security_roles` SET `areas`=CONCAT_WS(';', `areas`, '775')
	WHERE NOT `areas` REGEXP '[^0-9]?775[^0-9]?';

ALTER TABLE `0_stock_master` ADD COLUMN `no_purchase` tinyint(1) NOT NULL default '0' AFTER `no_sale`;
ALTER TABLE `0_stock_category` ADD COLUMN `dflt_no_purchase` tinyint(1) NOT NULL default '0' AFTER `dflt_no_sale`;

# added exchange rate field in grn_batch
ALTER TABLE `0_grn_batch` ADD COLUMN `rate` double NULL default '1' AFTER `loc_code`;
ALTER TABLE `0_users` CHANGE `query_size` `query_size` TINYINT(1) UNSIGNED NOT NULL DEFAULT 10; 

ALTER TABLE `0_users` ADD `save_report_selections` SMALLINT( 6 ) NOT NULL default '0' COMMENT 'Save Report Selection Days' AFTER `transaction_days`;
ALTER TABLE `0_users` ADD `use_date_picker` TINYINT(1) NOT NULL default '1' COMMENT 'Use Date Picker for all Date Values' AFTER `save_report_selections`;
ALTER TABLE `0_users` ADD `def_print_destination` TINYINT(1) NOT NULL default '0' COMMENT 'Default Report Destination' AFTER `use_date_picker`;
ALTER TABLE `0_users` ADD `def_print_orientation` TINYINT(1) NOT NULL default '0' COMMENT 'Default Report Orientation' AFTER `def_print_destination`;

INSERT INTO `0_sys_prefs` VALUES('no_zero_lines_amount', 'glsetup.sales', 'tinyint', 1, '1');
INSERT INTO `0_sys_prefs` VALUES('show_po_item_codes', 'glsetup.purchase', 'tinyint', 1, '0');
INSERT INTO `0_sys_prefs` VALUES('accounts_alpha', 'glsetup.general', 'tinyint', 1, '0');
INSERT INTO `0_sys_prefs` VALUES('loc_notification', 'glsetup.inventory', 'tinyint', 1, '0');
INSERT INTO `0_sys_prefs` VALUES('print_invoice_no', 'glsetup.sales', 'tinyint', 1, '0');
INSERT INTO `0_sys_prefs` VALUES('allow_negative_prices', 'glsetup.inventory', 'tinyint', 1, '1');
INSERT INTO `0_sys_prefs` VALUES('print_item_images_on_quote', 'glsetup.inventory', 'tinyint', 1, '0');
INSERT INTO `0_sys_prefs` VALUES('default_receival_required', 'glsetup.purchase', 'smallint', 6, '10');

# switching all MyISAM tables to InnoDB
ALTER TABLE `0_areas` ENGINE=InnoDB;
ALTER TABLE `0_attachments` ENGINE=InnoDB;
ALTER TABLE `0_bank_accounts` ENGINE=InnoDB;
ALTER TABLE `0_bom` ENGINE=InnoDB;
ALTER TABLE `0_chart_class` ENGINE=InnoDB;
ALTER TABLE `0_chart_master` ENGINE=InnoDB;
ALTER TABLE `0_chart_types` ENGINE=InnoDB;
ALTER TABLE `0_credit_status` ENGINE=InnoDB;
ALTER TABLE `0_currencies` ENGINE=InnoDB;
ALTER TABLE `0_cust_branch` ENGINE=InnoDB;
ALTER TABLE `0_debtors_master` ENGINE=InnoDB;
ALTER TABLE `0_exchange_rates` ENGINE=InnoDB;
ALTER TABLE `0_groups` ENGINE=InnoDB;
ALTER TABLE `0_item_codes` ENGINE=InnoDB;
ALTER TABLE `0_item_units` ENGINE=InnoDB;
ALTER TABLE `0_locations` ENGINE=InnoDB;
ALTER TABLE `0_movement_types` ENGINE=InnoDB;
ALTER TABLE `0_payment_terms` ENGINE=InnoDB;
ALTER TABLE `0_prices` ENGINE=InnoDB;
ALTER TABLE `0_printers` ENGINE=InnoDB;
ALTER TABLE `0_print_profiles` ENGINE=InnoDB;
ALTER TABLE `0_purch_data` ENGINE=InnoDB;
ALTER TABLE `0_quick_entries` ENGINE=InnoDB;
ALTER TABLE `0_quick_entry_lines` ENGINE=InnoDB;
ALTER TABLE `0_salesman` ENGINE=InnoDB;
ALTER TABLE `0_sales_pos` ENGINE=InnoDB;
ALTER TABLE `0_sales_types` ENGINE=InnoDB;
ALTER TABLE `0_security_roles` ENGINE=InnoDB;
ALTER TABLE `0_shippers` ENGINE=InnoDB;
ALTER TABLE `0_sql_trail` ENGINE=InnoDB;
ALTER TABLE `0_stock_category` ENGINE=InnoDB;
ALTER TABLE `0_suppliers` ENGINE=InnoDB;
ALTER TABLE `0_sys_prefs` ENGINE=InnoDB;
ALTER TABLE `0_tags` ENGINE=InnoDB;
ALTER TABLE `0_tag_associations` ENGINE=InnoDB;
ALTER TABLE `0_useronline` ENGINE=InnoDB;
ALTER TABLE `0_users` ENGINE=InnoDB;
ALTER TABLE `0_workcentres` ENGINE=InnoDB;

ALTER TABLE `0_gl_trans` CHANGE `type_no` `type_no` int(11) NOT NULL default '0';
ALTER TABLE `0_loc_stock` CHANGE `reorder_level` `reorder_level` double NOT NULL default '0';

# added dimensions in supplier documents
ALTER TABLE `0_supp_invoice_items` ADD COLUMN `dimension_id` int(11) NOT NULL DEFAULT '0' AFTER `memo_`;
ALTER TABLE `0_supp_invoice_items` ADD COLUMN `dimension2_id` int(11) NOT NULL DEFAULT '0' AFTER `dimension_id`;

UPDATE `0_supp_invoice_items` si
	LEFT JOIN `0_gl_trans` gl ON si.supp_trans_type=gl.`type` AND si.supp_trans_no=gl.type_no AND si.gl_code=gl.account
	SET si.dimension_id=gl.dimension_id, si.dimension2_id=gl.dimension2_id
WHERE si.grn_item_id=-1 AND (gl.dimension_id OR gl.dimension2_id);

ALTER TABLE `0_quick_entries` ADD COLUMN `usage` varchar(120) NULL AFTER `description`;
ALTER TABLE `0_quick_entry_lines` ADD COLUMN `memo` tinytext NOT NULL AFTER `amount`;

# multiply allocations to single jiurnal transaction
ALTER TABLE `0_cust_allocations` ADD COLUMN `person_id` int(11) DEFAULT NULL AFTER `id`;
UPDATE `0_cust_allocations` alloc LEFT JOIN `0_debtor_trans` trans ON alloc.trans_no_to=trans.trans_no AND alloc.trans_type_to=trans.type
	SET alloc.person_id = trans.debtor_no;

ALTER TABLE `0_supp_allocations` ADD COLUMN `person_id` int(11) DEFAULT NULL AFTER `id`;
UPDATE `0_supp_allocations` alloc LEFT JOIN `0_supp_trans` trans ON alloc.trans_no_to=trans.trans_no AND alloc.trans_type_to=trans.type
	SET alloc.person_id = trans.supplier_id;

ALTER TABLE `0_cust_allocations` DROP KEY `trans_type_from`;
ALTER TABLE `0_cust_allocations` ADD  UNIQUE KEY(`person_id`,`trans_type_from`,`trans_no_from`,`trans_type_to`,`trans_no_to`);
ALTER TABLE `0_supp_allocations` DROP KEY `trans_type_from`;
ALTER TABLE `0_supp_allocations` ADD  UNIQUE KEY(`person_id`,`trans_type_from`,`trans_no_from`,`trans_type_to`,`trans_no_to`);

# full support for any journal transaction
DROP TABLE IF EXISTS `0_journal`;
CREATE TABLE `0_journal` (
  `type` smallint(6) NOT NULL DEFAULT '0',
  `trans_no` int(11) NOT NULL DEFAULT '0',
  `tran_date` date DEFAULT '0000-00-00',
  `reference` varchar(60) NOT NULL DEFAULT '',
  `source_ref` varchar(60) NOT NULL DEFAULT '',
  `event_date` date DEFAULT '0000-00-00',
  `doc_date` date NOT NULL DEFAULT '0000-00-00',
  `currency` char(3) NOT NULL DEFAULT '',
  `amount` double NOT NULL DEFAULT '0',
  `rate` double NOT NULL DEFAULT '1',
  PRIMARY KEY `Type_and_Number` (`type`,`trans_no`),
  KEY `tran_date` (`tran_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ;

INSERT INTO `0_journal` (`type`, `trans_no`, `tran_date`, `reference`, `event_date`,`doc_date`,`currency`,`amount`)
 SELECT `gl`.`type`, `gl`.`type_no`, `gl`.`tran_date`, `ref`.`reference`, `gl`.`tran_date`,
 		`gl`.`tran_date`, `sys_curr`.`value`, SUM(IF(`gl`.`amount`>0,`gl`.`amount`,0))
 FROM `0_gl_trans` gl LEFT JOIN `0_refs` ref ON gl.type = ref.type AND gl.type_no=ref.id
 LEFT JOIN `0_sys_prefs` sys_curr ON `sys_curr`.`name`='curr_default'
 WHERE `gl`.`type` IN(0, 35)
 GROUP BY `type`,`type_no`;

# allow multiply customers.suppliers in single journal transaction
ALTER TABLE `0_debtor_trans` DROP PRIMARY KEY;
ALTER TABLE `0_debtor_trans` ADD  PRIMARY KEY (`type`,`trans_no`, `debtor_no`);
ALTER TABLE `0_supp_trans` DROP PRIMARY KEY;
ALTER TABLE `0_supp_trans` ADD  PRIMARY KEY (`type`,`trans_no`, `supplier_id`);

ALTER TABLE  `0_trans_tax_details` ADD COLUMN `reg_type` tinyint(1) DEFAULT NULL AFTER `memo`;

UPDATE `0_trans_tax_details` reg
	SET reg.reg_type=1
	WHERE reg.trans_type IN(20, 21);

UPDATE `0_trans_tax_details` reg
	SET reg.reg_type=0
	WHERE reg.trans_type IN(10, 11);

