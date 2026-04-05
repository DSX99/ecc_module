import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point

def inverse(a,p):
    return pow(a,p-2,p)

@cocotb.test()
async def full_tb(dut):
    
    cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())

    p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
    a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC4
    b = 0x00E8C2505DEDFC86DDC1BD0B2B6667F1DA34B82574761CB0E879BD081CFD0B6265EE3CB090F30D27614CB4574010DA90DD862EF9D4EBEE4761503190785A71C760
    q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF27E69532F48D89116FF22B8D4E0560609B4B38ABFAD2B85DCACDB1411F10B275
    gx = 0x03
    gy = 0x7503CFE87A836AE3A61B8816E25450E6CE5E1C93ACF1ABC1778064FDCBEFA921DF1626BE4FD036E93D75E6A50E3A41E98028FE5FC235F5B889A589CB5215F2A4
    gost_512_paramA = Curve(
        'id-tc26-gost-3410-12-512-paramSetA', 
        p, a, b, q, gx, gy
    )
    
    G = gost_512_paramA.G
    
    for i in range(0,5):
        print(i)
        
        k = random.randint(0,q-1)
        
        await RisingEdge(dut.clk)
        dut.rst.value=1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst.value=0
        await RisingEdge(dut.clk)
        
        # k=(1<<512)-q
            
        spi_send = ((G.x*(1<<512))%p) + (((G.y*(1<<512))%p)<<512) + (((a*(1<<512))%p)<<1024) + (p<<1536) + (k<<2048)
        
        dut.cs.value=1
        
        for j in range(0,2560):
            dut.spi_pad_MOSI.value=spi_send&1
            dut.spi_clk.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.spi_clk.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            spi_send=spi_send>>1
            
        for j in range(0,random.randint(1,100)):
            dut.spi_clk.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.spi_clk.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        
        dut.cs.value=0
        
        while dut.rdy.value!=1:
            await RisingEdge(dut.clk)
            
        await RisingEdge(dut.clk)
        
        got_x=0
        for i in range(0,512):
            dut.spi_clk.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.spi_clk.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = int(dut.spi_pad_MISO.value)
            got_x=(got_x>>1)+(got_bit<<511)
            
        
        got_y=0
        for i in range(0,512):
            dut.spi_clk.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.spi_clk.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = int(dut.spi_pad_MISO.value)
            got_y=(got_y>>1)+(got_bit<<511)
            
        P=k*G
        
        assert P.x == got_x and P.y == got_y, f"error P={P.x,P.y}, got = {got_x,got_y}"
        print(f"P={P.x,P.y}, got = {got_x,got_y}")

# @cocotb.test()
# async def inverse(dut):
    
#     cocotb.start_soon(Clock(dut.clk,1,units="ns").start())
#     p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
        
#     for i in range(0,100):
#         a=random.randint(0,p-1)
        
#         ans = pow(a,p-2,p)
        
#         dut.rst.value=1
#         await RisingEdge(dut.clk)
#         dut.rst.value=0
#         await RisingEdge(dut.clk)
        
#         dut.inv_in.value=a
#         dut.mod.value=p
#         dut.req.value=1
#         await RisingEdge(dut.clk)
#         dut.req.value=0
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         got = int(dut.inv_out.value)
        
#         assert got == ans, f"error, ans={ans}, got={got}"
    
    
# @cocotb.test()
# async def mod_mult(dut):
    
#     cocotb.start_soon(Clock(dut.clk,1,unit="ns").start())
#     p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
    
#     dut.rst.value=1
#     await RisingEdge(dut.clk)
#     dut.rst.value=0
#     await RisingEdge(dut.clk)    
    
#     for i in range(0,1000):
#         a=random.randint(0,p-1)
#         b=random.randint(0,p-1)
        
#         c=(a*b)%p
        
#         dut.mult_a.value=a
#         dut.mult_b.value=b
#         dut.mod.value=p
#         dut.req.value=1
#         await RisingEdge(dut.clk)    
#         dut.req.value=0
        
#         while(dut.rdy.value != 1):
#             await RisingEdge(dut.clk)    

#         got = int(dut.mult_out.value)
#         assert got == c, f"c={c}, got={got}"
#         if(i%100==0):
#             print(f"c={c},got={got}")
    
# @cocotb.test()
# async def point_alu(dut):
    
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())

#     p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
#     a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC4
#     b = 0x00E8C2505DEDFC86DDC1BD0B2B6667F1DA34B82574761CB0E879BD081CFD0B6265EE3CB090F30D27614CB4574010DA90DD862EF9D4EBEE4761503190785A71C760
#     q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF27E69532F48D89116FF22B8D4E0560609B4B38ABFAD2B85DCACDB1411F10B275
#     gx = 0x03
#     gy = 0x7503CFE87A836AE3A61B8816E25450E6CE5E1C93ACF1ABC1778064FDCBEFA921DF1626BE4FD036E93D75E6A50E3A41E98028FE5FC235F5B889A589CB5215F2A4
#     gost_512_paramA = Curve(
#         'id-tc26-gost-3410-12-512-paramSetA', 
#         p, a, b, q, gx, gy
#     )
    
#     G = gost_512_paramA.G
    
#     dut.rst.value=1
#     await RisingEdge(dut.clk)
#     dut.rst.value=0
#     await RisingEdge(dut.clk)
        
#     for i in range(0,100):
        
#         if i % 10==0:
#             print(i)
        
#         c = random.randint(0,q-1)
#         b = random.randint(0,q-1)
        
#         P1 = 2*G
#         P2 = 3*G
        
#         P_sum = P1+P2
#         P_dub = P1+P1
        
#         dut.P1_x.value = (P1.x * (1<<512))%p
#         dut.P1_y.value = (P1.y * (1<<512))%p
#         dut.P1_z.value = ((1<<512))%p
        
#         dut.P2_x.value = (P2.x * (1<<512))%p
#         dut.P2_y.value = (P2.y * (1<<512))%p
#         dut.P2_z.value = ((1<<512))%p
        
#         dut.mod.value = p
#         dut.a.value = (a*(1<<512))%p
        
#         dut.first.value=0
        
#         dut.req.value=1
#         await RisingEdge(dut.clk)
#         dut.req.value=0
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         got_x_sum = int(dut.Psum_x.value)
#         got_y_sum = int(dut.Psum_y.value)
#         got_z_sum = int(dut.Psum_z.value)
        
#         got_x_dub = int(dut.Pd_x.value)
#         got_y_dub = int(dut.Pd_y.value)
#         got_z_dub = int(dut.Pd_z.value)
    
#         R_inv=inverse(1<<512,p)
        
#         x_sum = (got_x_sum * R_inv)%p
#         x_dub = (got_x_dub * R_inv)%p
#         y_sum = (got_y_sum * R_inv)%p
#         y_dub = (got_y_dub * R_inv)%p
#         z_sum = (got_z_sum * R_inv)%p
#         z_dub = (got_z_dub * R_inv)%p
        
#         z_inv_sum = inverse(z_sum,p)
#         z_inv_dub = inverse(z_dub,p)
        
#         x_sum = (x_sum * (z_inv_sum ** 2))%p
#         x_dub = (x_dub * (z_inv_dub ** 2))%p
        
#         y_sum = (y_sum * (z_inv_sum ** 3))%p
#         y_dub = (y_dub * (z_inv_dub ** 3))%p
        
#         assert x_sum == P_sum.x and y_sum == P_sum.y, "error in sum"
#         assert x_dub == P_dub.x and y_dub == P_dub.y, "error in dub" 
    
#     dut._log.info("Successful!")
    

# @cocotb.test()
# async def test_modmul(dut):
    
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
#     dut.rst.value = 1
#     await RisingEdge(dut.clk)
#     dut.rst.value = 0
#     await RisingEdge(dut.clk)
        
#     r = (1<<512)-569
        
#     for i in range(0,100):
        
#         a = random.randint(0,(1<<512)-569)
#         b = random.randint(0,(1<<512)-569)
        
#         c = (a*b)%r
        
#         a_mont = (a * (1<<512))%r
#         b_mont = (b * (1<<512))%r
        
#         # print(a,b,a_mont,b_mont,r)
        
#         dut.a.value = a_mont
#         dut.b.value = b_mont
#         dut.mod.value = r
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
#         dut.req.value = 0
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         result_mont = int(dut.result.value)
        
#         dut.a.value = result_mont
#         dut.b.value = 1
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
#         dut.req.value = 0
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         result = int(dut.result.value)
        
#         assert c == result, "error"
    
#     dut._log.info("modmul Successful!")

# @cocotb.test()
# async def test(dut):
    
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())

#     r = (1<<512)-569
    
#     await RisingEdge(dut.clk)
        
#     for i in range(0,100):
        
#         a = random.randint(0,(1<<512)-569)
#         b = random.randint(0,(1<<512)-569)
        
#         c = (a+b)%r
        
#         dut.a.value = a
#         dut.b.value = b
#         dut.mod.value = r
#         dut.ctrl.value = 0
        
#         await RisingEdge(dut.clk)
        
#         result = int(dut.result.value)
        
#         assert c == result, "error"
        
#         c = (a-b)%r
        
#         dut.a.value = a
#         dut.b.value = b
#         dut.mod.value = r
#         dut.ctrl.value = 1
        
#         await RisingEdge(dut.clk)
        
#         result = int(dut.result.value)
        
#         assert c == result, "error"
    
#     dut._log.info("modadd Successful!")