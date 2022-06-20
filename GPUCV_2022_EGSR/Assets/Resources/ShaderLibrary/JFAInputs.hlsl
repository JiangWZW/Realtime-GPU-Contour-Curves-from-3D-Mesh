#ifndef E096A6DE_EACC_4999_8D82_05663FB81EC8
#define E096A6DE_EACC_4999_8D82_05663FB81EC8

#define JFA_STEPS 5u
#define JFA_MAX_RADIUS ((1 << JFA_STEPS))


struct JFAData
{
	uint2 coord;
	bool isSeed;
};


float EncodeJFAData(JFAData jfa)
{
	jfa.coord &= 0x00000fff; // max res: 4096x4096
	uint jfa_flag = jfa.isSeed;
	
	uint packed = jfa.coord.x;
	packed <<= 12u;			 // ____ ____ xxxx xxxx xxxx ____ ____ ____
	packed |= jfa.coord.y;	 // ____ ____ xxxx xxxx xxxx yyyy yyyy yyyy
	packed <<= 8u;			 // xxxx xxxx xxxx yyyy yyyy yyyy ____ ____
	packed |= jfa_flag;		 // xxxx xxxx xxxx yyyy yyyy yyyy ____ ___S
	
	return asfloat(packed);
}

JFAData DecodeJFAData(float jfaTexSample)
{
	uint packed = asuint(jfaTexSample);
							 // xxxx xxxx xxxx yyyy yyyy yyyy ____ ___S
	
	JFAData jfa;
	if (jfaTexSample != 0)
	{
		jfa.isSeed = (packed & 1);
		packed >>= 8u;			 // ____ ____ xxxx xxxx xxxx yyyy yyyy yyyy
		jfa.coord.y = (packed & 0x00000fff); // <== __ ____ yyyy yyyy yyyy
		packed >>= 12u;			 // ____ ____ ____ ____ ____ xxxx xxxx xxxx
		jfa.coord.x = (packed & 0x00000fff); // <== __ ____ xxxx xxxx xxxx
	}else
	{ // TODO: Optimize
		jfa.isSeed = false;
		jfa.coord = 0;
	}
	
	return jfa;
}




#endif /* E096A6DE_EACC_4999_8D82_05663FB81EC8 */
