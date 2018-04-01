module nfc.tag.felica.product;
import std.traits;
import std.format;
import std.conv;
import nfc.tag.felica;

struct ICProduct{
	this(ubyte[] codes, FeliCaType type, string name){
		_codes = codes;
		_name = name;
		_type = type;
	}
	ubyte[] codes(){
		return _codes;
	}
	string[] codesStr(){
		string[] codesStr;
		foreach(code; _codes){
			codesStr ~= format("%02X", code);
		}
		return codesStr;
	}
	string name(){
		return _name;
	}
	FeliCaType type(){
		return _type;
	}
	bool opEquals(FeliCaType type){
		return _type == type;
	}
	bool opEquals(ICProduct v){
		return opEquals(v.codes);
	}
	bool opEquals(ubyte[] codes){
		return _codes == codes;
	}
	bool opEquals(T)(T val)if(isIntegral!T){
		foreach(code; _codes){
			if(code == val){
				return true;
			}
		}
		return false;
	}
	string toString(){
		string str;
		str ~= "ICProduct(";
		str ~= "IC_Code[";
		foreach(i, code; codesStr){
			str ~= code;
			if((i+1) != codesStr.length){
				str ~= ",";
			}
		}
		str ~= "]";
		str ~= ", product:" ~ _name;
		str ~= ", type:" ~ _type;
		str ~= ")";
		return str;
	}
private:
	ubyte[] _codes;
	string _name;
	FeliCaType _type;
}
enum invalidProduct = ICProduct([], FeliCaType.FeliCa_UNKNOWN, "Invalid");
ICProduct getProduct(ubyte productCode){
	try{
		return productCode.to!(FeliCaStandard.Products);
	}catch(Exception e){
	}
	try{
		return productCode.to!(FeliCaLite.Products);
	}catch(Exception e){
	}
	try{
		return productCode.to!(FeliCaLiteS.Products);
	}catch(Exception e){
	}
	return ICProduct([productCode], FeliCaType.FeliCa_UNKNOWN, "Unknown Product");
}
enum FeliCaType: string{
	FeliCa_UNKNOWN = "Unknown FeliCa",
	FeliCa_STANDARD = "FeliCa Standard",
	FeliCa_LITE = "FeliCa Lite",
	FeliCa_LITES = "FeliCa Lite-S"
}
