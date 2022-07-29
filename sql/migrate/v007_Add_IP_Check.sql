CREATE TABLE IF NOT EXISTS `bccm_ip_cache` (
  `ip` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `response` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bccm_whitelist_ckey` (
  `ckey` varchar(50) NOT NULL,
  PRIMARY KEY (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bccm_asn_ban` (
  `asn` varchar(50) NOT NULL,
  PRIMARY KEY (`asn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
