module nfc.tag.felica.felicaLite;
import nfc.device;
import nfc.tag.felica;

class FeliCaLite: FeliCa{
	enum Products: ICProduct{
		RC_S965 = ICProduct([0xf0], FeliCaType.FeliCa_LITE, "RC-S965")
	}
	this(ubyte[] idm, ubyte[] ppm){
		super(idm, ppm);
	}
	this(ubyte[] idm, ubyte[] ppm, Device dev){
		super(idm, ppm, dev);
	}
}
