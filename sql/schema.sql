-- MySQL Schema for Popular Headers
--
-- Tables:
-- fetched_headers
-- fetches
-- headers
-- sites


DROP TABLE IF EXISTS `fetched_headers`;
CREATE TABLE `fetched_headers` (
  `site` varchar(128) NOT NULL DEFAULT '',
  `fetch_datetime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `header_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`site`,`fetch_datetime`,`header_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `fetches`;
CREATE TABLE `fetches` (
  `site` varchar(128) NOT NULL DEFAULT '',
  `fetch_datetime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `code` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`site`,`fetch_datetime`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `headers`;
CREATE TABLE `headers` (
  `header_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(128) NOT NULL,
  `value` varchar(128) NOT NULL,
  `first_added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_seen` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `job_offer` tinyint(1) NOT NULL,
  PRIMARY KEY (`header_id`),
  UNIQUE KEY `name` (`name`,`value`)
) ENGINE=InnoDB AUTO_INCREMENT=1604006 DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `sites`;
CREATE TABLE `sites` (
  `site` varchar(128) NOT NULL DEFAULT '',
  `source` varchar(128) DEFAULT NULL,
  `rank` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`site`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
