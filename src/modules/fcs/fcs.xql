xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "fcs.xqm";


let $project := request:get-parameter("project","")
let $config := config:config($project) 
					
return fcs:repo($config)					

