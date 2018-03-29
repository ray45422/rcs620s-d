module nfc.tag.felica.felicaLite;
import nfc.tag.felica;

class FeliCaLite: FeliCa{
	this(ubyte[] idm, ubyte[] ppm){
		super(idm, ppm);
	}
}
