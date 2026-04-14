import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point

WIDTH =256

p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD97
a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD94
b = 0xA6
m = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
x = 0x01
y = 0x008D91E471E0989CDA27DF505A453F2B7635294F2DDF23E3B122ACC99C9E9F1E14
gost_256_paramA = Curve(
    'id-tc26-gost-3410-12-256-paramSetA', 
    p, a, b, q, x, y
)

G = gost_256_paramA.G

def montgomery_ladder_step(XQP, XRP, M, YP, p):
    """
    Performs a single step of the Montgomery ladder based on the provided 
    ladder state and field prime p.
    """
    
    # 1. YR_bar = YP + 2 * M * XRP
    YR_bar = (YP + 2 * M * XRP) % p
    
    # 2. E = XQP - XRP
    E = (XQP - XRP) % p
    
    # 3. F = YR_bar * E
    F = (YR_bar * E) % p
    
    # 4. G = E^2
    G = pow(E, 2, p)
    
    # 5. XRP_prime = XRP * G
    XRP_prime = (XRP * G) % p
    
    # 6. H = YR_bar^2
    H = pow(YR_bar, 2, p)
    
    # 7. M_prime = M * F
    M_prime = (M * F) % p
    
    # 8. YP_prime = YP * F * G
    YP_prime = (YP * F * G) % p
    
    # 9. K = H + M_prime
    K = (H + M_prime) % p
    
    # 10. L = K + M_prime
    L = (K + M_prime) % p
    
    # 11. M_double_prime = XRP_prime - K
    M_double_prime = (XRP_prime - K) % p
    
    # 12. XSP = H * L
    XSP = (H * L) % p
    
    # 13. XTP = XRP_prime^2 + YP_prime
    XTP = (pow(XRP_prime, 2, p) + YP_prime) % p
    
    # 14. YP_double_prime = YP_prime * H
    YP_double_prime = (YP_prime * H) % p
    
    return XSP, XTP, M_double_prime, YP_double_prime


def inverse(a,p):
    return pow(a,p-2,p)

async def operation(dut ,first, second, operation, return_index):
    await RisingEdge(dut.clk)
    dut.rst.value=1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value=0
    await RisingEdge(dut.clk)
    
    spi_send = (first) + (second<<WIDTH) + (0<<(2*WIDTH)) + (0<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
    
    dut.do_operation.value=operation
    dut.cs.value=1
    
    for j in range(0,10*WIDTH):
        dut.spi_pad_MOSI.value=spi_send&1
        dut.spi_clk.value=1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.spi_clk.value=0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        spi_send=spi_send>>1
        
    for j in range(0,random.randint(100,1000)):
        dut.spi_clk.value=1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.spi_clk.value=0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut.cs.value=0
    
    while dut.rdy.value!=1:
        await RisingEdge(dut.clk)
    
    for i in range(1000):   
        await RisingEdge(dut.clk)
    
    mem=[]
    
    for j in range(0,10):
        mem.append(0)
        for i in range(0,256):
            dut.spi_clk.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.spi_clk.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = int(dut.spi_pad_MISO.value)
            mem[j]=(mem[j]>>1)+(got_bit<<(WIDTH-1)) 
    # print (hex(mem[return_index]))
    return mem[return_index]

@cocotb.test()
async def full_tb(dut):
    
    cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
    for i in range(0,5):
        print(i)
        k = random.randint(0,q-1)
        
        answ = k*G
        
        double_G_y= await operation(dut,G.y,G.y,2,2)
        assert double_G_y == ((2*G.y)%p) , "error in double_G_y"
        
        Z_sq = await operation(dut,double_G_y,double_G_y,1,2)
        assert Z_sq == (((2*G.y)**2)%p) , "error in Z_sq"
        
        print("done Z_sq")
        
        double_G_x = await operation(dut,G.x,G.x,2,2)
        assert double_G_x == ((2*G.x)%p) , "error in double_G_x"
        
        triple_G_x = await operation(dut,double_G_x,G.x,2,2)
        assert triple_G_x == ((3*G.x)%p) , "error in triple_G_x_sq"
        
        triple_G_x_sq = await operation(dut,triple_G_x,G.x,1,2)
        assert triple_G_x_sq == ((3*G.x**2)%p) , "error in G_x_sq"
        
        mZ = await operation(dut,triple_G_x_sq,a,2,2)
        assert mZ == ((3*G.x**2+a)%p) , "error in mZ"
        
        mZ_sq = await operation(dut,mZ,mZ,1,2)
        assert mZ_sq == ((mZ**2)%p) , "error in mZ_sq"
        
        G_x_Z_sq = await operation(dut,G.x,Z_sq,1,2)
        assert G_x_Z_sq == ((G.x*Z_sq)%p) , "error in G_x_Z_sq"
        
        double_G_x_Z_sq = await operation(dut,G_x_Z_sq,G_x_Z_sq,2,2)
        assert double_G_x_Z_sq == ((2*G.x*Z_sq)%p) , "error in double_G_x_Z_sq"
        
        triple_G_x_Z_sq = await operation(dut,double_G_x_Z_sq,G_x_Z_sq,2,2)
        assert triple_G_x_Z_sq == ((3*G.x*Z_sq)%p) , "error in triple_G_x_Z_sq"
        
        Xrp = await operation(dut,mZ_sq,triple_G_x_Z_sq,3,2)
        assert Xrp == (((mZ**2)-3*G.x*Z_sq)%p) , "error in Xrp"
        
        Y = await operation(dut, Z_sq, Z_sq, 1, 2)
        assert Y == ((Z_sq**2)%p), "error in Y"
        
        k = (k - (1<<256))%q
        
        XQP = 0
        XRP = Xrp
        M = mZ
        YP = Y
        
        dut.do_operation.value=0
        
        for wid in range(256):
            if (not wid%32):
                print(wid)
            await RisingEdge(dut.clk)
            dut.rst.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst.value=0
            await RisingEdge(dut.clk)
    
            # print("var k:",bin(k))
            
            bit = (k >> (255 - wid)) & 1
            # print("bit:",bit)
            if bit:
                spi_send = (XQP) + (XRP<<WIDTH) + (M<<(2*WIDTH)) + (YP<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
            else:
                spi_send = (XRP) + (XQP<<WIDTH) + (M<<(2*WIDTH)) + (YP<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
            dut.cs.value=1
            
            for j in range(0,10*WIDTH):
                dut.spi_pad_MOSI.value=spi_send&1
                dut.spi_clk.value=1
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                dut.spi_clk.value=0
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                spi_send=spi_send>>1
                
            for j in range(0,random.randint(100,1000)):
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
            
            mem=[]
            
            for j in range(0,10):
                mem.append(0)
                for i in range(0,256):
                    dut.spi_clk.value=1
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    dut.spi_clk.value=0
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    got_bit = int(dut.spi_pad_MISO.value)
                    mem[j]=(mem[j]>>1)+(got_bit<<(WIDTH-1))  
            
            if bit:
                # should_be = montgomery_ladder_step(XQP, XRP, M, YP, p)
                XQP = mem[6]
                XRP = mem[5]
                M = mem[7]
                YP = mem[4]
                # got_tot = (XQP,XRP,M,YP)
            else:
                # should_be = montgomery_ladder_step(XRP, XQP, M, YP, p)
                XRP = mem[6]
                XQP = mem[5]
                M = mem[7]
                YP = mem[4]
                # got_tot = (XRP,XQP,M,YP)
            
            
            # assert got_tot == should_be, f"error got:{got_tot}, should be:{should_be}"
            
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
            
        YP_demont = YP%p
        M_demont = M%p
        XQP_demont = XQP%p
        XRP_demont = XRP%p
            
        M_sq = await operation(dut, M, M, 1, 2)
        assert M_sq == ((M**2)%p), "error in M_sq"

        M_sq_XQP = await operation(dut, M_sq, XQP, 3, 2)
        assert M_sq_XQP == ((M_demont**2 - XQP_demont)%p), "error in M_sq_XQP"
        
        M_sq_XQP_XRP = await operation(dut, M_sq_XQP, XRP, 3, 2)
        assert M_sq_XQP_XRP == ((M_demont**2 - XQP_demont - XRP_demont)%p), "error in M_sq_XQP_XRP"
        
        numer = await operation(dut, double_G_y, M_sq_XQP_XRP, 1, 2)
        assert numer == (2*G.y*(M_demont**2 - XQP_demont - XRP_demont))%p , "error in numer"

        denom = await operation(dut, triple_G_x, YP, 1, 2)
        assert denom == (3*G.x * (YP_demont))%p , "error in denom"
        
        inv = 1

        for i in range(WIDTH):
            if(not i%32):
                print(i)
            bit = ((p-2)>>(WIDTH-1-i))&1
            inv = await operation(dut, inv, inv, 1, 2)
            if bit:
                inv = await operation(dut, inv, denom, 1, 2)    \
                    
        assert inv == inverse(denom,p), "error in inversion"
                
        Z_inv = await operation(dut, numer, inv, 1, 2)
        assert Z_inv == ((numer)*inverse(denom,p))%p , "error in Z_inv"    
            
        Z_inv_sq = await operation(dut, Z_inv, Z_inv, 1, 2)
        assert Z_inv_sq == (Z_inv*Z_inv)%p , "error in Z_inv_sq"    

        Z_inv_sq_XQP = await operation(dut, XQP, Z_inv_sq, 1, 2)
        assert Z_inv_sq_XQP == ((XQP_demont)*Z_inv*Z_inv)%p, "error in Z_inv_sq_XQP"
        
        x_q = await operation(dut, G.x, Z_inv_sq_XQP, 2, 2)
        assert x_q == (G.x + (XQP_demont)*Z_inv*Z_inv)%p, "error in x_q"
        
        assert answ.x == x_q, f"error answ={hex(answ.x)}, got = {hex(x_q)}"
        print(f"idk how it works")

# @cocotb.test()
# async def inverse_fermat(dut):
    
#     cocotb.start_soon(Clock(dut.clk,1,unit="ns").start())

#     denom = random.randint(0,p-1)

#     inv = 1

#     for i in range(WIDTH):
#         if(not i%32):
#             print(i)
#         bit = ((p-2)>>(WIDTH-1-i))&1
#         inv = await operation(dut, inv, inv, 1, 2)
#         if bit:
#             inv = await operation(dut, inv, denom, 1, 2) 
                
#     assert inv == inverse(denom,p), "error in inversion"

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
#         d = random.randint(0,q-1)
        
#         P1 = c*G
#         P2 = d*G
        
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
# async def test_modmul(dut): #mont mult
    
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
#     dut.rst.value = 1
#     await RisingEdge(dut.clk)
#     dut.rst.value = 0
#     await RisingEdge(dut.clk)
        
#     r = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD97
        
#     for i in range(0,100):
#         await RisingEdge(dut.clk)
#         dut.req.value = 0
#         await RisingEdge(dut.clk)
#         await RisingEdge(dut.clk)
#         await RisingEdge(dut.clk)
        
        
#         a = random.randint(0,r)
#         b = random.randint(0,r)
        
#         c = (a*b)%r
        
#         a_mont = (a * (1<<256))%r
#         b_mont = (b * (1<<256))%r
        
#         # print(a,b,a_mont,b_mont,r)
        
#         dut.a.value = a_mont
#         dut.b.value = b_mont
#         dut.mod.value = r
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         result_mont = int(dut.result.value)
#         assert result_mont == (c * (1<<256))%r ,"error in first multiply"
        
#         await RisingEdge(dut.clk)
#         dut.req.value = 0
#         await RisingEdge(dut.clk)
#         await RisingEdge(dut.clk)
#         await RisingEdge(dut.clk)
        
#         dut.a.value = result_mont
#         dut.b.value = 1
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         result = int(dut.result.value)
        
#         assert c == result, f"error with {hex(a),hex(b),hex(c)}"
    
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