//DX10 - FLAT SHADER
//Digital Arts & Entertainment


//GLOBAL VARIABLES
//****************
float4x4 gWorld : WORLD;
float4x4 gWorldViewProj : WORLDVIEWPROJECTION;
float4x4 gViewInverse : VIEWINVERSE;
float3 gLightDirection = float3(-0.577f, -0.577f, 0.577f);

bool gShowFins = true;
bool gShowShells = false;

float4 gColorDiffuse = float4(0.7f, 0.47f, 0.f, 1.0f);
float gFurLength = 20.0f;
int gLayers = 30;
float gOpacityThreshold = 0.3f;

//TEXTURES
//********
Texture2D gDiffuseMap;
Texture2D gFinOpacityMap;
Texture2D gShellOpacityMap;

//STATES
//******
DepthStencilState FinsDepthState
{
    DepthEnable = TRUE;
    DepthWriteMask = ZERO;
};

DepthStencilState DepthState
{
    DepthEnable = TRUE;
    DepthWriteMask = ALL;
};

BlendState EnableBlending
{
    BlendEnable[0] = TRUE;
    SrcBlend = SRC_ALPHA;
    DestBlend = INV_SRC_ALPHA;
};

BlendState NoBlending
{
    BlendEnable[0] = FALSE;
};

RasterizerState NoCulling
{
    CullMode = NONE;
};
RasterizerState BackFaceCulling
{
    CullMode = FRONT;
};

//SAMPLER STATES
//**************
SamplerState samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap; // or Mirror or Clamp or Border
    AddressV = Wrap; // or Mirror or Clamp or Border
};

//VS IN & OUT
//***********
struct VS_DATA
{
    float3 pos : POSITION;
    float3 normal : NORMAL;
    float3 worldPos : COLOR0;
    float2 texCoord : TEXCOORD;
};
struct GS_DATA
{
    float4 pos : SV_POSITION;
    float3 normal : NORMAL;
    float2 texCoord : TEXCOORD0;
    int layer : TEXCOORD1;
};

//BASE VERTEX SHADER
//******************
GS_DATA VS(VS_DATA input)
{
    GS_DATA output = (GS_DATA) 0;
	// Step 1:	convert position into float4 and multiply with matWorldViewProj
    output.pos = mul(float4(input.pos, 1.0f), gWorldViewProj);
	// Step 2:	rotate the normal: NO TRANSLATION
	//			this is achieved by clipping the 4x4 to a 3x3 matrix, 
	//			thus removing the postion row of the matrix
    output.normal = normalize(mul(input.normal, (float3x3) gWorld));
    output.texCoord = input.texCoord;
    return output;
}

//BASE PIXEL SHADER
//*****************
float4 PS(GS_DATA input) : SV_TARGET
{
    float4 diffuseColor = gDiffuseMap.Sample(samLinear, input.texCoord);
    float3 color_rgb = diffuseColor.rgb;
    float color_a = diffuseColor.a;
	
	//HalfLambert Diffuse :)
    float diffuseStrength = dot(input.normal, -gLightDirection);
    diffuseStrength = diffuseStrength * 0.5 + 0.5;
    diffuseStrength = saturate(diffuseStrength);
    color_rgb = color_rgb * diffuseStrength;
	
	//Darken
    color_rgb *= 0.8f;

    return float4(color_rgb, color_a);
}

VS_DATA MainVS(VS_DATA input)
{
    return input;
}

//FINS
//****
void CreateVertex(inout TriangleStream<GS_DATA> triStream, float3 pos, float3 normal, float2 texCoord, int layerIndex)
{
    GS_DATA temp = (GS_DATA) 0;
	
    temp.pos = mul(float4(pos, 1.0f), gWorldViewProj);
    temp.normal = mul(float4(normal, 1.0f), gWorld);
    temp.texCoord = texCoord;
	
    temp.layer = layerIndex;
		
    triStream.Append(temp);
}

[maxvertexcount(4)]
void FinGS(line VS_DATA vertices[2], inout TriangleStream<GS_DATA> triStream)
{
    VS_DATA v1 = vertices[0], v2 = vertices[1];
    float3 v1_worldNormal = mul(v1.normal, (float3x3) gWorld);
    float3 v2_worldNormal = mul(v2.normal, (float3x3) gWorld);

    //normal of the edge
    float3 normal = normalize((v1_worldNormal + v2_worldNormal) / 2);
    //normal of the new quad (the fin)
    float3 quadNormal = normalize(cross(normal, abs(v1.pos - v2.pos)));

    //extra length compared to shells
    float offset = 1.1f;
    float length = gFurLength * 0.01;
	
	//*************
    
    //eye vector
    float3 view = normalize(v1.pos + v1_worldNormal - gViewInverse[3].xyz);

    //if sil < 0.3 the edge is a silhouette edge and can be rendered
    float sil = dot(v1_worldNormal, view) * dot(v2_worldNormal, view);
    if (sil > 0.05f)
        return;
	
	//*************
    float2 uv_lt = float2(1.0f, 0.1f), uv_lb = float2(1.0f, 0.95f);
    float2 uv_rt = float2(0.0f, 0.1f), uv_rb = float2(0.0f, 0.95f);

    CreateVertex(triStream, v1.pos, quadNormal, uv_lb, 0);
    CreateVertex(triStream, v2.pos, quadNormal, uv_rb, 0);
    CreateVertex(triStream, v1.pos + v1.normal * length * offset, quadNormal, uv_lt, 0);
    CreateVertex(triStream, v2.pos + v2.normal * length * offset, quadNormal, uv_rt, 0);
	
    triStream.RestartStrip();
}

float4 FinPS(GS_DATA input) : SV_TARGET
{
    if (!gShowFins)
        return float4(0, 0, 0, 0);
		
    float4 color = gColorDiffuse;
	
    float diffuseStrength = 0.5f;
    color *= diffuseStrength;
    float furAlpha = gFinOpacityMap.Sample(samLinear, input.texCoord).r;
    color.a = (1 - furAlpha);
    if (color.a <= 0.1f)
        discard;
	
    return color;
}

//SHELLS
//******
//amount of layers * 3 vertices for a triangle
[maxvertexcount(32 * 3)]
void ShellGS(triangle VS_DATA vertices[3], inout TriangleStream<GS_DATA> triStream)
{
    VS_DATA v1 = vertices[0], v2 = vertices[1], v3 = vertices[2];
    float length = gFurLength / 100;
    float offset = length / gLayers;
	
	[loop]
    for (float i = 0; i < gLayers; ++i)
    {
        v1.pos = v1.pos + v1.normal * offset;
        v2.pos = v2.pos + v2.normal * offset;
        v3.pos = v3.pos + v3.normal * offset;

        CreateVertex(triStream, v1.pos, v1.normal, v1.texCoord, i);
        CreateVertex(triStream, v2.pos, v2.normal, v2.texCoord, i);
        CreateVertex(triStream, v3.pos, v3.normal, v3.texCoord, i);

        triStream.RestartStrip();
    }
}

float4 ShellPS(GS_DATA input) : SV_TARGET
{
    if (!gShowShells)
        return float4(0, 0, 0, 0);
    float4 diffuseColor = gDiffuseMap.Sample(samLinear, input.texCoord);
    float3 color_rgb = diffuseColor.rgb;
    float color_a = diffuseColor.a;
	
    float diffuseStrength = dot(-input.normal, gLightDirection);
    diffuseStrength = diffuseStrength * 0.5 + 0.5;
    diffuseStrength = saturate(diffuseStrength);
    color_rgb = color_rgb * diffuseStrength;
		
	//opacity
    float4 opacity = gShellOpacityMap.Sample(samLinear, input.texCoord);
    color_a = (1 - opacity.r) * (1 - (float) input.layer / (3 * gLayers));
	//color_a = (1 - opacity.r);
	//increase brightness at the end of strands
    color_rgb *= 0.8f + (float) input.layer / (2 * gLayers);
	
    if (color_a <= gOpacityThreshold)
        discard;

    return float4(color_rgb, color_a);
}

//TECHNIQUES
//**********
technique10 Default
{
	//base
    pass P0
    {
        SetRasterizerState(BackFaceCulling);

        SetVertexShader(CompileShader(vs_4_0, VS()));
        SetPixelShader(CompileShader(ps_4_0, PS()));
    }
	
	//fins
    pass P1
    {
        SetRasterizerState(NoCulling);
		
        SetDepthStencilState(FinsDepthState, 0);
		
        SetBlendState(EnableBlending, float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFFF);
        SetVertexShader(CompileShader(vs_4_0, MainVS()));
        SetGeometryShader(CompileShader(gs_4_0, FinGS()));
        SetPixelShader(CompileShader(ps_4_0, FinPS()));
    }
	
	//shells
    pass P2
    {
        SetRasterizerState(NoCulling);
		
        SetDepthStencilState(DepthState, 0);
		
        SetBlendState(EnableBlending, float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFF);
        SetVertexShader(CompileShader(vs_4_0, MainVS()));
        SetGeometryShader(CompileShader(gs_4_0, ShellGS()));
        SetPixelShader(CompileShader(ps_4_0, ShellPS()));
    }
	
}