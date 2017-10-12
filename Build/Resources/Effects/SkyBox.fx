SamplerState samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

TextureCube m_CubeMap : CubeMap;

RasterizerState gRS_FrontCulling
{
    CullMode = NONE;
};

DepthStencilState Depth
{
    DepthFunc = LESS_EQUAL;
};

cbuffer cbChangesEveryFrame
{
	matrix matWorldViewProj : WorldViewProjection;
}

struct VS_IN
{
	float3 posL : POSITION;
};

struct VS_OUT
{
	float4 posH : SV_POSITION;
	float3 texC : TEXCOORD;
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
VS_OUT VS( VS_IN vIn )
{
	VS_OUT vOut = (VS_OUT)0;
	
	// set z = w so that z/w = 1 (i.e., skydome always on far plane).
    vOut.posH = mul(float4(vIn.posL, 0.0f), matWorldViewProj).xyww;
	// use local vertex position as cubemap lookup vector
    vOut.texC = vIn.posL;

	return vOut;
}
//--------------------------------------------------------------------------------------
// Pixel XMeshShader
//--------------------------------------------------------------------------------------
float4 PS( VS_OUT pIn): SV_Target
{
    float4 color = m_CubeMap.Sample(samLinear, pIn.texC);
	return color;
}

technique10 Render
{
    pass P0
    {
        SetRasterizerState(gRS_FrontCulling);
        SetDepthStencilState(Depth, 0);
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PS() ) );
    }
}