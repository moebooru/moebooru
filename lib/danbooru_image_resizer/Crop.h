#ifndef CROP_H
#define CROP_H

#include "Filter.h"
#include <memory>
using namespace std;

class Crop: public Filter
{
public:
	Crop(auto_ptr<Filter> pOutput);
	void SetCrop(int iTop, int iBottom, int iLeft, int iRight);
	bool Init(int iWidth, int iHeight, int iBPP);
	bool WriteRow(uint8_t *pNewRow);
	bool Finish() { return m_pOutput->Finish(); }
	const char *GetError() const { return m_pOutput->GetError(); }

private:
	auto_ptr<Filter> m_pOutput;

	int m_iRow;
	int m_iTop;
	int m_iBottom;
	int m_iLeft;
	int m_iRight;
	int m_iSourceWidth;
	int m_iSourceHeight;
	int m_iSourceBPP;
};

#endif
