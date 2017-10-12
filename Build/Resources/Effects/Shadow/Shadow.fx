float4x4 gWorld;
float4x4 gLightViewProj;

bool gIsSkinned = false;
float4x4 gBones[100];
 
DepthStencilState depthStencilState
{
    DepthEnable = TRUE;
    DepthWriteMask = ALL;
};

RasterizerState rasterizerState
{
    FillMode = SOLID;
    CullMode = NONE;
};

struct VS_INPUT
{
    float3 pos : POSITION;
    float4 blendIndices : BLENDINDICES;
    float4 blendWeights : BLENDWEIGHTS;
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
float4 ShadowMapVS(VS_INPUT input) : SV_POSITION
{
    if (gIsSkinned)
    {
        float4 originalPosition = float4(input.pos, 1);
        float4 transformedPosition = 0;
	
        for (int i = 0; i < 4; ++i)
        {
            if (input.blendIndices[i] > -1)
            {
                transformedPosition += mul(originalPosition, gBones[input.blendIndices[i]] * input.blendWeights[i]);
            }
        }
        return mul(transformedPosition, mul(gWorld, gLightViewProj));
    }
    else
        return mul(float4(input.pos, 1.0f), mul(gWorld, gLightViewProj));
}
 
//--------------------------------------------------------------------------------------
// Pixel Shaders
//--------------------------------------------------------------------------------------
void ShadowMapPS_VOID(float4 position : SV_POSITION)
{
}

float4 ShadowMapPS(float4 position : SV_POSITION) : SV_TARGET
{
    return float4(0.0f, 1.0f, 0.0f, 1.0f);
}

technique11 GenerateShadows
{
    pass P0
    {
        SetRasterizerState(rasterizerState);
        SetDepthStencilState(depthStencilState, 0);
        SetVertexShader(CompileShader(vs_4_0, ShadowMapVS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_4_0, ShadowMapPS()));
    }
}