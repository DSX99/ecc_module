import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point

def inverter(a,p):
    return pow(a,p-2,p)

# --- Helper: Jacobian Addition Golden Model ---
def jacobian_add_reference(p1, p2, p, c):
    """
    Computes Point Addition based on the specific formulas 
    provided in the Verilog comments.
    """
    x1, y1, z1 = p1
    x2, y2, z2 = p2

    # Match the Verilog internal logic:
    # u1 = (p1_x * p2_z**2) % p
    u1 = (x1 * pow(z2, 2, p)) % p
    # u2 = (p2_x * p1_z**2) % p
    u2 = (x2 * pow(z1, 2, p)) % p
    # s1 = (p1_y * p2_z**3) % p
    s1 = (y1 * pow(z2, 3, p)) % p
    # s2 = (p2_y * p1_z**3) % p
    s2 = (y2 * pow(z1, 3, p)) % p
    
    r = (s1 - s2) % p
    h = (u1 - u2) % p
    
    # g = h^3
    g = pow(h, 3, p)
    # v = u1 * h^2
    v = (u1 * pow(h, 2, p)) % p
    
    # p3_x = (r^2 + g - 2*v) % p
    x3 = (pow(r, 2, p) + g - 2*v) % p
    # p3_y = (r*(v - x3) - s1*g) % p
    y3 = (r * (v - x3) - s1 * g) % p
    # p3_z = (z1 * z2 * h) % p
    z3 = (z1 * z2 * h) % p

    # print("u1: ",hex(u1),"\n","u2: ",hex(u2),"\n","s1: ",hex(s1),"\n","s2: ",hex(u1),"\n","r: ",hex(r),"\n","g: ",hex(g),"\n","h: ",hex(h),"\n","v: ",hex(v),"\n")
    # print("x3: ",hex(x3),"\n","y3: ",hex(y3),"\n","z3: ",hex(z3),"\n")

    return (x3, y3, z3)

def point_double(p1_x,p1_y,p):
    p1_z=1
    M=(3*(p1_x-p1_z**2)*(p1_x+p1_z**2))%p
    T=(p1_y**4)%p
    S=(4*p1_x*p1_y**2)%p
    p3_x=(M**2-2*S)%p
    p3_y=(M*(S-p3_x)-8*T)%p
    p3_z=(2*p1_y*p1_z)%p
    
    return p3_x,p3_y,p3_z

async def reset_dut(dut):
    dut.rst.value = 1
    dut.req.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

# @cocotb.test()
# async def test_point_add_basic(dut):
#     """Test a single point addition with random coordinates"""
    
#     # Parameters
#     width = int(dut.WIDTH.value)
#     c_val = int(dut.C.value)
#     p = (1 << width) - c_val
    
#     # Start Clock
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
#     # Reset
#     await reset_dut(dut)

#     # Generate Random Input Points
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
    
#     # for i in range(0,1000):
#     #     P1 = random.randint(1,1<<511) * G
#     #     P2 = random.randint(1,1<<511) * G
#     #     # Apply Inputs
#     #     dut.P1_x.value = P1.x
#     #     dut.P1_y.value = P1.y
#     #     dut.P1_z.value = 1
#     #     dut.P2_x.value = P2.x
#     #     dut.P2_y.value = P2.y
#     #     dut.P2_z.value = 1
        
#     #     p1 = (P1.x,P1.y,1)
#     #     p2 = (P2.x,P2.y,1)
        
#     #     dut.req.value = 1
#     #     await RisingEdge(dut.clk)
#     #     dut.req.value = 0

#     #     # Wait for Ready
#     #     while str(dut.rdy.value) != "1":
#     #         await RisingEdge(dut.clk)

#     #     # Capture Outputs
#     #     got_x = int(dut.P3_x.value)
#     #     got_y = int(dut.P3_y.value)
#     #     got_z = int(dut.P3_z.value)

#     #     # Calculate Expected
#     #     exp_x, exp_y, exp_z = jacobian_add_reference(p1, p2, p, c_val)

#     #     # Assertions
#     #     assert got_x == exp_x, f"X Mismatch: Got {hex(got_x)}, Exp {hex(exp_x)}"
#     #     assert got_y == exp_y, f"Y Mismatch: Got {hex(got_y)}, Exp {hex(exp_y)}"
#     #     assert got_z == exp_z, f"Z Mismatch: Got {hex(got_z)}, Exp {hex(exp_z)}"
#     for i in range(0,1):
#         P1 = random.randint(0,q-1) * G
#         P2 = random.randint(0,q-1) * G
#         # Apply Inputs
#         dut.P1_x.value = P1.x
#         dut.P1_y.value = P1.y
#         dut.P1_z.value = 1
#         dut.P2_x.value = P2.x
#         dut.P2_y.value = P2.y
#         dut.P2_z.value = 1
        
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
#         dut.req.value = 0

#         while str(dut.rdy.value) != "1":
#             await RisingEdge(dut.clk)

#         # got_x_norm = int(dut.P3_x_norm.value)
#         # got_y_norm = int(dut.P3_y_norm.value)
        
#         got_x = int(dut.P3_x.value)
#         got_y = int(dut.P3_y.value)
#         got_z = int(dut.P3_z.value)
        
#         inv = inverter(got_z,p)
        
#         got_x_norm = (got_x * inv **2)%p
#         got_y_norm = (got_y * inv **3)%p
        
#         P_sum = P1 + P2

#         assert (got_x_norm == P_sum.x and got_y_norm == P_sum.y), "Simulation wrong"
    
#     dut._log.info("Point Addition Successful!")

# @cocotb.test()
# async def test_point_double(dut):
    
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
#     await reset_dut(dut)

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
    
#     for i in range(0,1000):
        
#         if(i%100 == 0):
#             print(i)
        
#         P1 = random.randint(0,q-1) * G
        
#         dut.P1_x.value = P1.x
#         dut.P1_y.value = P1.y
#         dut.P1_z.value = 1
        
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
#         dut.req.value = 0

#         while str(dut.rdy.value) != "1":
#             await RisingEdge(dut.clk)

#         got_x = int(dut.P3_x.value)
#         got_y = int(dut.P3_y.value)
#         got_z = int(dut.P3_z.value)
        
#         sim_x, sim_y, sim_z = point_double(P1.x,P1.y,p)
        
#         assert got_x == sim_x and got_y == sim_y and got_z == sim_z, f"diff with sim \n should be {sim_x, sim_y,sim_z} \n got {got_x, got_y, got_z}"
        
#         x3 = (got_x*(inverter(got_z,p)**2))%p
#         y3 = (got_y*(inverter(got_z,p)**3))%p
        
#         P_sum = P1 + P1

#         assert (x3 == P_sum.x and y3 == P_sum.y), "diff with lib"
    
#     dut._log.info("Point doubling Successful!")

# @cocotb.test()
# async def test_point_mult(dut):
    
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
    
#     for i in range(0,100):
        
#         await reset_dut(dut)
        
#         if(i%10 == 0):
#             print(i)
        
#         d = random.randint(0,q-1)

#         P1 = d * G
        
#         dut.G_x.value = G.x
#         dut.G_y.value = G.y
#         dut.a.value = d
        
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
#         dut.req.value = 0

#         while str(dut.rdy.value) != "1":
#             await RisingEdge(dut.clk)

#         got_x = int(dut.P_x.value)
#         got_y = int(dut.P_y.value)
#         got_z = int(dut.P_z.value)
           
#         x3 = (got_x*(inverter(got_z,p)**2))%p
#         y3 = (got_y*(inverter(got_z,p)**3))%p

#         assert (x3 == P1.x and y3 == P1.y), " \n diff with lib " + f"should be {P1.x, P1.y} \n got {x3,y3}\n with initial cong {d} \n"
#         # print(f"passed {d}")
    
#     dut._log.info("Point mult Successful!")

@cocotb.test()
async def test_point_mult_with_inv(dut):
    
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
        
        await reset_dut(dut)
        
        
        print(i)
        
        # d = random.randint(0,q-1)
        d=1
        
        P1 = d * G
        
        dut.G_x.value = (G.x * (1<<512))%p
        dut.G_y.value = (G.y * (1<<512))%p
        dut.a.value = d
        
        dut.req.value = 1
        await RisingEdge(dut.clk)
        dut.req.value = 0

        while str(dut.rdy.value) != "1":
            await RisingEdge(dut.clk)

        got_x = (int(dut.P_x.value) *(1<<1024))%p
        got_y = (int(dut.P_y.value) *(1<<(512*3)))%p
        got_z = int(dut.P_z.value)
           
        assert (got_x == P1.x and got_y == P1.y), " \n diff with lib " + f"should be {P1.x, P1.y} \n got {got_x,got_y}\n with initial cong {d} \n"
        # print(f"passed {d}")
    
    dut._log.info("Point mult Successful!")

# @cocotb.test()
# async def test_modmul(dut):
#     cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
#     p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
    
#     for i in range(0,1<<20):
        
#         if(i%1000==0):
#             print(i)
        
#         await reset_dut(dut)
        
#         a = random.randint(0,p-1)
#         b = random.randint(0,p-1)
        
#         dut.a.value = a
#         dut.b.value = b
#         dut.req.value = 1
#         await RisingEdge(dut.clk)
#         dut.req.value = 1
        
#         while(dut.rdy.value!=1):
#             await RisingEdge(dut.clk)
        
#         res = (a*b)%p
        
#         assert res == dut.out.value, "Error"
    
#     print("pass")