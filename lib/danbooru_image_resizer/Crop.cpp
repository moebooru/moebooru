#include "Crop.h"

Crop::Crop(auto_ptr<Filter> pOutput):
	m_pOutput(pOutput)
{
	m_iRow = 0;
}

void Crop::SetCrop(int iTop, int iBottom, int iLeft, int iRight)
{
	m_iTop = iTop;
	m_iBottom = iBottom;
	m_iLeft = iLeft;
	m_iRight = iRight;
}

bool Crop::Init(int iWidth, int iHeight, int iBPP)
{
	m_iSourceWidth = iWidth;
	m_iSourceHeight = iHeight;
	m_iSourceBPP = iBPP;

	return m_pOutput->Init(m_iRight - m_iLeft, m_iBottom - m_iTop, iBPP);
}

bool Crop::WriteRow(uint8_t *pNewRow)
{
	if(m_iRow >= m_iTop && m_iRow < m_iBottom)
	{
		pNewRow += m_iLeft * m_iSourceBPP;
		if(!m_pOutput->WriteRow(pNewRow))
			return false;
	}

	++m_iRow;

	return true;
}

