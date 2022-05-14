import groovy.json.*

JsonSlurper slurper = new JsonSlurper()
JsonOutput builder = new JsonOutput()



// json templates
def tplText = new File("MCM/config/RMR_Rads/config.json").text

// old ini
def oldVarsMatched = new File("MCM/config/RMR_Rads/settings.ini").text =~ /(?:\[([^\]\r\n]+)\])|(?:([^;=\r\n]+?)=([^;\r\n]*?)(?:\s*[;\r\n]))/
def oldVars = [:]
def curSection
oldVarsMatched.each{oldVar ->
	if (oldVar[1]) {
		if (oldVar[1] == 'Slider0' || !(oldVar[1] ==~ /Slider\d+/)) {
			curSection = oldVar[1]
			oldVars[curSection] = [:]
		} else {
			curSection = null
		}
	} else if (curSection && oldVar[2]) {
		oldVars[curSection][oldVar[2]] = oldVar[3]
	}
}


def replacer
replacer = {json ->
	if (json instanceof Map) {
		def remove = []
		def add = [:]
		json.each{k,v->
			if (k ==~ /^(.+)--join\(([^\)]+)\)$/ && v instanceof List) {
				def nk = k.replaceAll(/^(.+)--join\(([^\)]+)\)$/, '$1')
				def nv = v.join(k.replaceAll(/^(.+)--join\(([^\)]+)\)$/, '$2'))
				remove << k
				add[nk] = nv
			} else {
				json[k] = replacer(json[k])
			}
		}
		json.removeAll{rk,kv->remove.contains(rk)}
		json += add
	} else if (json instanceof List) {
		json.eachWithIndex{child,idx->json[idx]=replacer(child)}
	}
	return json
}


// create json and ini files
// json
def tpl = slurper.parseText(tplText)
tpl = replacer(tpl)
File output = new File("MCM/config/RMR_Rads/config.json")
output.text = builder.prettyPrint(builder.toJson(tpl))

// ini
def newVarsMatched = output.text =~ /"id"\s*:\s*"([^"]+?)(?::([^"]+))?"/
def newVars = [:]
newVarsMatched.each{newVar ->
	def section = newVar[2]
	if (section) {
		if (!newVars[section]) {
			newVars[section] = [:]
		}
		newVars[section][newVar[1]] = oldVars.getAt(section ==~ /Slider\d+/ ? 'Slider0' : section)?.getAt(newVar[1])
	}
}
StringBuilder sb = new StringBuilder()
newVars.each{section, vars ->
	sb << "\n\n\n[${section}]\n"
	vars.each{name, val ->
		sb << "${name}=${val}\n"
	}
}

File iniDefault = new File("MCM/config/RMR_Rads/settings.ini")
iniDefault.text = sb