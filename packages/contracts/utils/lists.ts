export enum ChainId {
    Mainnet = "0x1",
    SapphireMainnet = "0x5afe",
    SapphireTestnet = "0x5aff",
    BnbChainMainnet = "0x38",
    BnbChainTestnet = "0x61",
    PolygonTestnet = "0x13881",
    SapphireLocal = "0x5afd",
    Goerli = "0x5",
    ArbitrumGoerli = "0x66eed",
    Arbitrum = "0xa4b1",
    Polygon = "0x89",
}

export const TESTNETS = [
  ChainId.BnbChainTestnet,
  ChainId.Goerli,
  ChainId.SapphireTestnet,
];

export const SAPPHIRE_TESTNETS = [
    ChainId.SapphireTestnet,
    ChainId.SapphireLocal,
]

export const chainIdToEnumChainId = (chainid: string): ChainId => {
    return `0x${Number(chainid).toString(16)}` as ChainId;
}

export const SAPPHIRE_CHAINIDS = [ChainId.SapphireMainnet, ChainId.SapphireTestnet, ChainId.SapphireLocal];

export const CELER_MESSAGE_BUS: Record<string, string> = {
    [ChainId.BnbChainMainnet]: "0x95714818fdd7a5454f73da9c777b3ee6ebaeea6b",
    [ChainId.SapphireMainnet]: "0x9Bb46D5100d2Db4608112026951c9C965b233f4D",
    [ChainId.SapphireTestnet]: "0x9Bb46D5100d2Db4608112026951c9C965b233f4D",
    [ChainId.BnbChainTestnet]: "0xAd204986D6cB67A5Bc76a3CB8974823F43Cb9AAA",
    [ChainId.PolygonTestnet]: "0x7d43AABC515C356145049227CeE54B608342c0ad",
    [ChainId.SapphireLocal]: "0x9Bb46D5100d2Db4608112026951c9C965b233f4D",
    [ChainId.Goerli]: "0xF25170F86E4291a99a9A560032Fe9948b8BcFBB2",
    [ChainId.ArbitrumGoerli]: "0x7d43AABC515C356145049227CeE54B608342c0ad",
    [ChainId.Polygon]: "0xaFDb9C40C7144022811F034EE07Ce2E110093fe6",
    [ChainId.Mainnet]: "0x4066d196a423b2b3b8b054f4f40efb47a74e200c",
    [ChainId.Arbitrum]: "0x3ad9d0648cdaa2426331e894e980d0a5ed16257f",
};

export const NATIVE_WRAPPERS: Record<string, string> = {
    [ChainId.BnbChainMainnet]: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    [ChainId.Mainnet]: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    [ChainId.Arbitrum]: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
    [ChainId.Polygon]: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
}

export type AssetInfo = {
    token: string;
    name: string;
    symbol: string;
    decimals: number;
}

export const ASSETS_LIST: Record<string, AssetInfo[]> = {
    [ChainId.BnbChainMainnet]: [
        {
            token: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
            name: "bscBNB",
            symbol: "bscBNB",
            decimals: 18
        },
        {
            token: "0x55d398326f99059fF775485246999027B3197955",
            name: "bscUSDT",
            symbol: "bscUSDT",
            decimals: 18
        }
    ],
    [ChainId.Arbitrum]: [
        {
            token: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
            name: "arbETH",
            symbol: "arbETH",
            decimals: 18
        }
    ],
    [ChainId.Polygon]: [
        {
            token: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
            name: "polyPOL",
            symbol: "polyPOL",
            decimals: 18
        }
    ],
    [ChainId.Mainnet]: [
        {
            token: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
            name: "ethETH",
            symbol: "ethETH",
            decimals: 18
        },
        {
            token: "0xdac17f958d2ee523a2206206994597c13d831ec7",
            name: "ethUSDT",
            symbol: "ethUSDT",
            decimals: 6
        },
        {
            token: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            name: "ethUSDC",
            symbol: "ethUSDC",
            decimals: 6
        },
        {
            token: "0x6b175474e89094c44da98b954eedeac495271d0f",
            name: "ethDAI",
            symbol: "ethDAI",
            decimals: 18
        },
        {
            token: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
            name: "ethWBTC",
            symbol: "ethWBTC",
            decimals: 8
        }
    ],

}