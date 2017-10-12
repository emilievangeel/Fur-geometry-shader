//=============================================================================
//// Shader uses position and texture
//=============================================================================
SamplerState samPoint
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Mirror;
    AddressV = Mirror;
};

Texture2D gTexture;

/// Create Depth Stencil State (ENABLE DEPTH WRITING)
DepthStencilState gDSS_EnableDepthWriting
{
	DepthEnable = TRUE;
};
/// Create Rasterizer State (Backface culling) 
RasterizerState gRS_BackCulling
{
	CullMode = BACK;
};


//IN/OUT STRUCTS
//--------------
struct VS_INPUT
{
    float3 Position : POSITION;
	float2 TexCoord : TEXCOORD0;

};

struct PS_INPUT
{
    float4 Position : SV_POSITION;
	float2 TexCoord : TEXCOORD1;
};


//VERTEX SHADER
//-------------
PS_INPUT VS(VS_INPUT input)
{
	PS_INPUT output = (PS_INPUT)0;
	// Set the Position
	output.Position = float4(input.Position, 1);
	// Set the TexCoord
	output.TexCoord = input.TexCoord;
	
	return output;
}


//PIXEL SHADER
//------------
float4 PS(PS_INPUT input): SV_Target
{
    // Step 1: sample the texture
    float3 sampledTexture = gTexture.Sample(samPoint, input.TexCoord);

	// Calculate sepia
    float4 color = float4(sampledTexture, 1);
    color.r = (sampledTexture.r * 0.393) + (sampledTexture.g * 0.769) + (sampledTexture.b * 0.189);
    color.g = (sampledTexture.r * 0.349) + (sampledTexture.g * 0.686) + (sampledTexture.b * 0.168);
    color.b = (sampledTexture.r * 0.272) + (sampledTexture.g * 0.534) + (sampledTexture.b * 0.131);
 
	// Step 3: return the color
    return color;
}


//TECHNIQUE
//---------
technique11 Sepia
{
    pass P0
    {          
        // Set states...
		SetRasterizerState(gRS_BackCulling);
		SetDepthStencilState(gDSS_EnableDepthWriting, 0);
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PS() ) );
    }
}

